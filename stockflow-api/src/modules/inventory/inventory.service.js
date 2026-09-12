const { pool } = require('../../config/db');
const { v4: uuidv4 } = require('uuid');
const AppError = require('../../utils/AppError');
const { getPagination, buildMeta } = require('../../utils/pagination');
const inventoryRepo = require('./inventory.repository');

const listStock = async (businessId, query) => {
  const { page, limit, offset } = getPagination(query);
  const { search, lowStockOnly } = query;

  const { rows, total } = await inventoryRepo.findAllStock(businessId, {
    search,
    limit,
    offset,
  });

  let filtered = rows;
  if (lowStockOnly === 'true') {
    filtered = rows.filter((r) => r.stock_status === 'LOW_STOCK');
  }

  return { inventory: filtered, meta: buildMeta(total, page, limit) };
};

const getStockByProduct = async (businessId, productId) => {
  const stock = await inventoryRepo.findStockByProduct(businessId, productId);
  if (!stock) throw new AppError('Product not found', 404);
  return stock;
};

const getLowStockProducts = async (businessId) => {
  return inventoryRepo.findLowStock(businessId);
};

const getOutOfStockProducts = async (businessId) => {
  return inventoryRepo.findOutOfStock(businessId);
};

const createTransaction = async (businessId, userId, { productId, type, quantity, note }) => {
  const allowedTypes = ['STOCK_IN', 'STOCK_OUT', 'ADJUSTMENT'];
  if (!allowedTypes.includes(type)) {
    throw new AppError(`Invalid type. Allowed: ${allowedTypes.join(', ')}`, 400);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const currentQty = await inventoryRepo.lockForUpdate(productId, businessId, client);
    if (currentQty === null) throw new AppError('Product not found in inventory', 404);

    let delta;
    let quantityAfter;

    if (type === 'STOCK_IN') {
      delta = Math.abs(parseFloat(quantity));
      quantityAfter = currentQty + delta;
    } else if (type === 'STOCK_OUT') {
      delta = -Math.abs(parseFloat(quantity));
      quantityAfter = currentQty + delta;
      if (quantityAfter < 0) {
        throw new AppError(
          `Insufficient stock. Available: ${currentQty}, Requested: ${Math.abs(delta)}`,
          400
        );
      }
    } else if (type === 'ADJUSTMENT') {
      // Physical count semantics: entered quantity is the counted target stock
      quantityAfter = parseFloat(quantity);
      if (isNaN(quantityAfter) || quantityAfter < 0) {
        throw new AppError('Adjusted physical stock count cannot be negative', 400);
      }
      delta = quantityAfter - currentQty;
    }

    await inventoryRepo.updateQuantity(productId, quantityAfter, businessId, client);

    const tx = await inventoryRepo.createTransaction({
      id:             uuidv4(),
      businessId,
      productId,
      userId,
      type,
      quantity:       delta,
      quantityBefore: currentQty,
      quantityAfter,
      note,
    }, client);

    await client.query('COMMIT');
    return tx;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const listTransactions = async (businessId, query) => {
  const { page, limit, offset } = getPagination(query);
  const { productId, type, startDate, endDate } = query;

  const { rows, total } = await inventoryRepo.findTransactions(businessId, {
    productId, type, startDate, endDate, limit, offset,
  });

  return { transactions: rows, meta: buildMeta(total, page, limit) };
};

module.exports = {
  listStock, getStockByProduct, getLowStockProducts, getOutOfStockProducts,
  createTransaction, listTransactions,
};
