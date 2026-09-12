process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'super_secret_test_key_minimum_32_characters_long_123';

const salesService = require('../../src/modules/sales/sales.service');
const salesRepo = require('../../src/modules/sales/sales.repository');
const inventoryRepo = require('../../src/modules/inventory/inventory.repository');
const { pool } = require('../../src/config/db');

describe('Sales Transaction & Inventory Integrity Unit Tests', () => {
  let mockClient;
  const businessId = '11111111-1111-1111-1111-111111111111';
  const cashierId  = '22222222-2222-2222-2222-222222222222';
  const productA   = '33333333-3333-3333-3333-333333333333';
  const productB   = '44444444-4444-4444-4444-444444444444';

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

  describe('1. Cart & Item Validations', () => {
    it('rejects empty sales payload with 400', async () => {
      await expect(
        salesService.createSale(businessId, cashierId, { items: [] })
      ).rejects.toThrow(/Cart cannot be empty/);
    });

    it('rejects checkout when product does not exist', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([]);

      await expect(
        salesService.createSale(businessId, cashierId, {
          items: [{ productId: productA, quantity: 1 }],
        })
      ).rejects.toThrow(/One or more products not found/);

      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('rejects checkout if any product is inactive', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productA, name: 'Discontinued Soda', is_active: false, selling_price: '2.50' },
      ]);

      await expect(
        salesService.createSale(businessId, cashierId, {
          items: [{ productId: productA, quantity: 1 }],
        })
      ).rejects.toThrow(/is inactive/);

      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });
  });

  describe('2. Stock Checks & Insufficient Inventory Protection', () => {
    it('rejects transaction when requested quantity exceeds available stock', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productA, name: 'Mineral Water', is_active: true, selling_price: '1.50' },
      ]);
      // Only 3 available in stock
      jest.spyOn(inventoryRepo, 'lockMultipleForUpdate').mockResolvedValue({
        [productA]: 3,
      });

      // Request 5 units
      await expect(
        salesService.createSale(businessId, cashierId, {
          items: [{ productId: productA, quantity: 5 }],
        })
      ).rejects.toThrow(/Insufficient stock for 'Mineral Water'. Available: 3, Requested: 5/);

      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('rejects transaction when discount exceeds sale subtotal', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productA, name: 'Apple', is_active: true, selling_price: '10.00' },
      ]);
      jest.spyOn(inventoryRepo, 'lockMultipleForUpdate').mockResolvedValue({
        [productA]: 10,
      });

      // Subtotal = $10.00, but discount = $15.00
      await expect(
        salesService.createSale(businessId, cashierId, {
          items: [{ productId: productA, quantity: 1 }],
          discountAmount: 15.00,
        })
      ).rejects.toThrow(/Discount cannot exceed sale subtotal/);

      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });
  });

  describe('3. Atomicity & Rollback Guarantee', () => {
    it('rolls back completely if a database error occurs while writing sale items', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productA, name: 'Coffee', is_active: true, selling_price: '5.00' },
      ]);
      jest.spyOn(inventoryRepo, 'lockMultipleForUpdate').mockResolvedValue({
        [productA]: 10,
      });
      jest.spyOn(salesRepo, 'createSale').mockResolvedValue({ id: 'sale_123' });
      // Simulate fatal DB write error on line item creation
      jest.spyOn(salesRepo, 'createSaleItem').mockRejectedValue(new Error('Connection lost'));

      await expect(
        salesService.createSale(businessId, cashierId, {
          items: [{ productId: productA, quantity: 2 }],
        })
      ).rejects.toThrow('Connection lost');

      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
      expect(mockClient.query).not.toHaveBeenCalledWith('COMMIT');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('successfully commits transaction, updates stock, and writes audit records on valid checkout', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productA, name: 'Coffee', is_active: true, selling_price: '5.00' },
        { id: productB, name: 'Cookie', is_active: true, selling_price: '2.00' },
      ]);
      jest.spyOn(inventoryRepo, 'lockMultipleForUpdate').mockResolvedValue({
        [productA]: 10,
        [productB]: 20,
      });
      jest.spyOn(salesRepo, 'createSale').mockResolvedValue({ id: 'sale_success_1' });
      jest.spyOn(salesRepo, 'createSaleItem').mockResolvedValue({ id: 'item_1' });
      jest.spyOn(inventoryRepo, 'updateQuantity').mockResolvedValue();
      jest.spyOn(inventoryRepo, 'createTransaction').mockResolvedValue({});

      const result = await salesService.createSale(businessId, cashierId, {
        items: [
          { productId: productA, quantity: 2 }, // $10
          { productId: productB, quantity: 3 }, // $6
        ],
        taxAmount: 1.60,
        discountAmount: 1.00,
        paymentMethod: 'CARD',
      });

      expect(result.sale).toBeDefined();
      expect(result.items.length).toBe(2);

      // Verify inventory deductions
      expect(inventoryRepo.updateQuantity).toHaveBeenCalledWith(productA, 8, businessId, mockClient);
      expect(inventoryRepo.updateQuantity).toHaveBeenCalledWith(productB, 17, businessId, mockClient);

      // Verify audit transaction records
      expect(inventoryRepo.createTransaction).toHaveBeenCalledTimes(2);

      // Verify atomic commit
      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
      expect(mockClient.release).toHaveBeenCalled();
    });
  });
});
