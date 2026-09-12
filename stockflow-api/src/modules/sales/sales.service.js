const { pool } = require('../../config/db');
const { v4: uuidv4 } = require('uuid');
const AppError = require('../../utils/AppError');
const { getPagination, buildMeta } = require('../../utils/pagination');
const salesRepo = require('./sales.repository');
const inventoryRepo = require('../inventory/inventory.repository');

/**
 * Create a sale atomically.
 * All 7 steps succeed or the entire transaction is rolled back.
 */
const createSale = async (businessId, cashierId, saleData) => {
  const { items, paymentMethod, discountAmount = 0, taxAmount = 0, note } = saleData;

  if (!items || items.length === 0) throw new AppError('Cart cannot be empty', 400);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // ── Step 1: Validate all products ─────────────────────────────────────
    const productIds = items.map((i) => i.productId);
    const products   = await salesRepo.findProductsById(productIds, businessId, client);

    if (products.length !== productIds.length) {
      throw new AppError('One or more products not found', 404);
    }

    const inactiveProd = products.find((p) => !p.is_active);
    if (inactiveProd) throw new AppError(`Product '${inactiveProd.name}' is inactive`, 400);

    const productMap = Object.fromEntries(products.map((p) => [p.id, p]));

    // ── Step 2: Lock inventory rows & validate stock ───────────────────────
    const inventoryMap = await inventoryRepo.lockMultipleForUpdate(productIds, businessId, client);

    for (const item of items) {
      const available = inventoryMap[item.productId];
      if (available === undefined) {
        throw new AppError(`Inventory record missing for product ${item.productId}`, 500);
      }
      if (available < item.quantity) {
        throw new AppError(
          `Insufficient stock for '${productMap[item.productId].name}'. ` +
          `Available: ${available}, Requested: ${item.quantity}`,
          400
        );
      }
    }

    // ── Step 3: Calculate totals server-side (SECURITY: strictly use DB prices) ──
    let subtotal = 0;
    const enrichedItems = items.map((item) => {
      const product = productMap[item.productId];
      // Force price from DB - never trust client unitPrice
      const unitPrice = parseFloat(product.selling_price);
      if (isNaN(unitPrice) || unitPrice < 0) {
        throw new AppError(`Invalid product price for '${product.name}'`, 500);
      }

      const qty = parseFloat(item.quantity);
      if (isNaN(qty) || qty <= 0) {
        throw new AppError(`Invalid quantity for '${product.name}'`, 400);
      }

      const lineSubtotal = unitPrice * qty;
      const itemDisc = parseFloat(item.discount || 0);

      if (isNaN(itemDisc) || itemDisc < 0) {
        throw new AppError(`Invalid discount for product '${product.name}'`, 400);
      }
      if (itemDisc > lineSubtotal) {
        throw new AppError(
          `Discount for product '${product.name}' cannot exceed line item total`,
          400
        );
      }

      const lineTotal = parseFloat((lineSubtotal - itemDisc).toFixed(2));
      subtotal += lineTotal;

      return {
        productId: item.productId,
        quantity: qty,
        unitPrice,
        discount: itemDisc,
        lineTotal,
        productName: product.name,
      };
    });

    subtotal = parseFloat(subtotal.toFixed(2));

    const parsedDiscount = parseFloat(discountAmount || 0);
    if (isNaN(parsedDiscount) || parsedDiscount < 0) {
      throw new AppError('Discount amount cannot be negative', 400);
    }
    if (parsedDiscount > subtotal) {
      throw new AppError('Discount cannot exceed sale subtotal', 400);
    }

    const parsedTax = parseFloat(taxAmount || 0);
    if (isNaN(parsedTax) || parsedTax < 0) {
      throw new AppError('Tax amount cannot be negative', 400);
    }

    const totalAmount = parseFloat((subtotal - parsedDiscount + parsedTax).toFixed(2));

    // ── Step 4: Create sale ───────────────────────────────────────────────
    const saleId = uuidv4();
    const sale   = await salesRepo.createSale({
      id: saleId, businessId, cashierId, status: 'COMPLETED',
      paymentMethod: paymentMethod || 'CASH',
      subtotal, discountAmount: parsedDiscount, taxAmount: parsedTax, totalAmount, note,
    }, client);

    // ── Step 5: Create sale items ─────────────────────────────────────────
    const saleItems = [];
    for (const si of enrichedItems) {
      const created = await salesRepo.createSaleItem({
        id: uuidv4(), saleId, productId: si.productId,
        productName: si.productName, unitPrice: si.unitPrice,
        quantity: si.quantity, discount: si.discount, lineTotal: si.lineTotal,
      }, client);
      saleItems.push(created);
    }

    // ── Step 6 & 7: Update inventory + create audit records ───────────────
    for (const si of enrichedItems) {
      const quantityBefore = inventoryMap[si.productId];
      const quantityAfter  = quantityBefore - si.quantity;

      await inventoryRepo.updateQuantity(si.productId, quantityAfter, businessId, client);

      await inventoryRepo.createTransaction({
        id:             uuidv4(),
        businessId,
        productId:      si.productId,
        userId:         cashierId,
        type:           'SALE',
        quantity:       -si.quantity,
        quantityBefore,
        quantityAfter,
        referenceId:    saleId,
        note:           `Sale #${saleId.slice(0, 8)}`,
      }, client);
    }

    await client.query('COMMIT');
    return { sale, items: saleItems };

  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

/**
 * Void a sale — reverses all inventory changes atomically.
 */
const voidSale = async (businessId, saleId, userId) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const sale = await salesRepo.findByIdForUpdate(businessId, saleId, client);
    if (!sale) throw new AppError('Sale not found', 404);
    if (sale.status !== 'COMPLETED') {
      throw new AppError(`Cannot void a sale with status '${sale.status}'`, 400);
    }

    const items = await salesRepo.findItems(saleId, client);

    for (const item of items) {
      const currentQty = await inventoryRepo.lockForUpdate(item.product_id, businessId, client);
      if (currentQty === null) continue; // product deleted — skip, don't fail

      const quantityAfter = currentQty + parseFloat(item.quantity);
      await inventoryRepo.updateQuantity(item.product_id, quantityAfter, businessId, client);

      await inventoryRepo.createTransaction({
        id:             uuidv4(),
        businessId,
        productId:      item.product_id,
        userId,
        type:           'RETURN',
        quantity:       parseFloat(item.quantity),
        quantityBefore: currentQty,
        quantityAfter,
        referenceId:    saleId,
        note:           `Void of sale #${saleId.slice(0, 8)}`,
      }, client);
    }

    const updated = await salesRepo.updateStatus(saleId, 'VOIDED', client);

    await client.query('COMMIT');
    return updated;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const listSales = async (businessId, userId, roleName, query) => {
  const { page, limit, offset } = getPagination(query);
  const { status, paymentMethod, startDate, endDate, cashierId } = query;

  // Cashiers see only their own sales
  const effectiveCashierId = roleName === 'CASHIER' ? userId : cashierId;

  const { rows, total } = await salesRepo.findAll(businessId, {
    cashierId: effectiveCashierId, status, paymentMethod, startDate, endDate, limit, offset,
  });

  return { sales: rows, meta: buildMeta(total, page, limit) };
};

const getSaleById = async (businessId, saleId, userId, roleName) => {
  const sale = await salesRepo.findById(businessId, saleId);
  if (!sale) throw new AppError('Sale not found', 404);

  // Cashier can only read their own sales
  if (roleName === 'CASHIER' && sale.cashier_id !== userId) {
    throw new AppError('Sale not found', 404);
  }

  const items = await salesRepo.findItems(saleId);
  return { ...sale, items };
};

const getReceipt = async (businessId, saleId, userId, roleName) => {
  const data = await salesRepo.findReceiptData(businessId, saleId);
  if (!data) throw new AppError('Sale not found', 404);

  if (roleName === 'CASHIER' && data.sale.cashier_id !== userId) {
    throw new AppError('Sale not found', 404);
  }

  return data;
};

module.exports = { createSale, voidSale, listSales, getSaleById, getReceipt };
