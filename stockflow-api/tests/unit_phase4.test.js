process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'super_secret_test_key_minimum_32_characters_long_123';

const categoriesService = require('../src/modules/categories/categories.service');
const categoriesRepo = require('../src/modules/categories/categories.repository');
const productsService = require('../src/modules/products/products.service');
const productsRepo = require('../src/modules/products/products.repository');
const inventoryService = require('../src/modules/inventory/inventory.service');
const inventoryRepo = require('../src/modules/inventory/inventory.repository');
const salesService = require('../src/modules/sales/sales.service');
const salesRepo = require('../src/modules/sales/sales.repository');
const { pool } = require('../src/config/db');

describe('Phase 4 Core Business Functionality Unit Tests', () => {
  let mockClient;

  beforeEach(() => {
    mockClient = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
      release: jest.fn(),
    };
    jest.spyOn(pool, 'connect').mockResolvedValue(mockClient);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  // ── 1. Category Protected Deletion ──────────────────────────────────────
  describe('1. Categories Management & Protected Deletion', () => {
    const businessId = '11111111-1111-1111-1111-111111111111';
    const categoryId = '22222222-2222-2222-2222-222222222222';

    it('rejects deletion of a category referenced by active products', async () => {
      jest.spyOn(categoriesRepo, 'findById').mockResolvedValue({ id: categoryId, name: 'Beverages' });
      // 3 active products still reference this category
      jest.spyOn(categoriesRepo, 'countActiveProducts').mockResolvedValue(3);

      await expect(categoriesService.deleteCategory(businessId, categoryId)).rejects.toThrow(
        /Cannot delete category: 3 active product/
      );
    });

    it('allows category deletion when no active products reference it', async () => {
      jest.spyOn(categoriesRepo, 'findById').mockResolvedValue({ id: categoryId, name: 'Beverages' });
      jest.spyOn(categoriesRepo, 'countActiveProducts').mockResolvedValue(0);
      jest.spyOn(categoriesRepo, 'remove').mockResolvedValue({ id: categoryId });

      const res = await categoriesService.deleteCategory(businessId, categoryId);
      expect(res.id).toBe(categoryId);
    });
  });

  // ── 2. Product Role-Aware Data & Deactivation ───────────────────────────
  describe('2. Product Role-Aware Data & Deactivation', () => {
    const businessId = '11111111-1111-1111-1111-111111111111';
    const productId  = '33333333-3333-3333-3333-333333333333';

    it('strips cost_price for CASHIER role', async () => {
      jest.spyOn(productsRepo, 'findById').mockResolvedValue({
        id: productId,
        name: 'Coffee',
        cost_price: '12.00',
        selling_price: '25.00',
      });
      jest.spyOn(productsRepo, 'findImages').mockResolvedValue([]);

      const product = await productsService.getProductById(businessId, productId, 'CASHIER');
      expect(product.cost_price).toBeUndefined();
      expect(product.selling_price).toBe('25.00');
    });

    it('preserves cost_price for OWNER or MANAGER role', async () => {
      jest.spyOn(productsRepo, 'findById').mockResolvedValue({
        id: productId,
        name: 'Coffee',
        cost_price: '12.00',
        selling_price: '25.00',
      });
      jest.spyOn(productsRepo, 'findImages').mockResolvedValue([]);

      const product = await productsService.getProductById(businessId, productId, 'OWNER');
      expect(product.cost_price).toBe('12.00');
    });

    it('soft-deletes (deactivates) product instead of permanently removing', async () => {
      jest.spyOn(productsRepo, 'softDelete').mockResolvedValue({ id: productId, is_active: false });

      const result = await productsService.softDeleteProduct(businessId, productId);
      expect(result.is_active).toBe(false);
    });
  });

  // ── 3. Inventory Movement Semantics ──────────────────────────────────────
  describe('3. Inventory Movement Semantics', () => {
    const businessId = '11111111-1111-1111-1111-111111111111';
    const userId     = '44444444-4444-4444-4444-444444444444';
    const productId  = '33333333-3333-3333-3333-333333333333';

    it('STOCK_IN: adds quantity to current stock', async () => {
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(20);
      let updatedQty = null;
      jest.spyOn(inventoryRepo, 'updateQuantity').mockImplementation(async (_, q) => {
        updatedQty = q;
      });
      jest.spyOn(inventoryRepo, 'createTransaction').mockResolvedValue({ id: 'tx-1' });

      await inventoryService.createTransaction(businessId, userId, {
        productId,
        type: 'STOCK_IN',
        quantity: 10,
        note: 'Shipment received',
      });

      expect(updatedQty).toBe(30);
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
    });

    it('STOCK_OUT: subtracts quantity and checks stock sufficiency', async () => {
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(15);
      let updatedQty = null;
      jest.spyOn(inventoryRepo, 'updateQuantity').mockImplementation(async (_, q) => {
        updatedQty = q;
      });
      jest.spyOn(inventoryRepo, 'createTransaction').mockResolvedValue({ id: 'tx-2' });

      await inventoryService.createTransaction(businessId, userId, {
        productId,
        type: 'STOCK_OUT',
        quantity: 5,
        note: 'Damaged goods',
      });

      expect(updatedQty).toBe(10);
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
    });

    it('ADJUSTMENT: treats entered quantity as physical count and computes delta', async () => {
      // Current stock is 50, but shelf audit found physical count is 42
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(50);
      let updatedQty = null;
      let recordedTx = null;
      jest.spyOn(inventoryRepo, 'updateQuantity').mockImplementation(async (_, q) => {
        updatedQty = q;
      });
      jest.spyOn(inventoryRepo, 'createTransaction').mockImplementation(async (tx) => {
        recordedTx = tx;
        return tx;
      });

      await inventoryService.createTransaction(businessId, userId, {
        productId,
        type: 'ADJUSTMENT',
        quantity: 42,
        note: 'Physical count verified on shelf',
      });

      expect(updatedQty).toBe(42);
      expect(recordedTx.quantityBefore).toBe(50);
      expect(recordedTx.quantityAfter).toBe(42);
      expect(recordedTx.quantity).toBe(-8); // delta = 42 - 50 = -8
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
    });
  });

  // ── 4. Void Sale Safety & Atomic Inventory Restoration ──────────────────
  describe('4. Void Sale Safety', () => {
    const businessId = '11111111-1111-1111-1111-111111111111';
    const userId     = '44444444-4444-4444-4444-444444444444';
    const saleId     = '55555555-5555-5555-5555-555555555555';
    const prodA      = '66666666-6666-6666-6666-666666666666';

    it('rejects voiding if sale status is not COMPLETED', async () => {
      jest.spyOn(salesRepo, 'findByIdForUpdate').mockResolvedValue({
        id: saleId,
        status: 'VOIDED',
      });

      await expect(salesService.voidSale(businessId, saleId, userId)).rejects.toThrow(
        /Cannot void a sale with status 'VOIDED'/
      );
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });

    it('restores inventory quantities and creates RETURN audit record atomically', async () => {
      jest.spyOn(salesRepo, 'findByIdForUpdate').mockResolvedValue({
        id: saleId,
        status: 'COMPLETED',
      });
      jest.spyOn(salesRepo, 'findItems').mockResolvedValue([
        { product_id: prodA, quantity: 3 },
      ]);
      // Current stock before void is 7
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(7);
      let restoredQty = null;
      jest.spyOn(inventoryRepo, 'updateQuantity').mockImplementation(async (_, q) => {
        restoredQty = q;
      });
      let recordedReturnTx = null;
      jest.spyOn(inventoryRepo, 'createTransaction').mockImplementation(async (tx) => {
        recordedReturnTx = tx;
        return tx;
      });
      jest.spyOn(salesRepo, 'updateStatus').mockResolvedValue({ id: saleId, status: 'VOIDED' });

      const voided = await salesService.voidSale(businessId, saleId, userId);

      expect(restoredQty).toBe(10); // 7 + 3 = 10
      expect(recordedReturnTx.type).toBe('RETURN');
      expect(recordedReturnTx.quantity).toBe(3);
      expect(recordedReturnTx.quantityBefore).toBe(7);
      expect(recordedReturnTx.quantityAfter).toBe(10);
      expect(voided.status).toBe('VOIDED');
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
    });
  });
});
