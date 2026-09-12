process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'super_secret_test_key_minimum_32_characters_long_123';

const inventoryService = require('../../src/modules/inventory/inventory.service');
const inventoryRepo = require('../../src/modules/inventory/inventory.repository');
const { pool } = require('../../src/config/db');

describe('Inventory Movement & Validation Unit Tests', () => {
  let mockClient;
  const businessId = '11111111-1111-1111-1111-111111111111';
  const userId     = '22222222-2222-2222-2222-222222222222';
  const productId  = '33333333-3333-3333-3333-333333333333';

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

  describe('1. Input Validation', () => {
    it('rejects invalid transaction type', async () => {
      await expect(
        inventoryService.createTransaction(businessId, userId, {
          productId,
          type: 'INVALID_TYPE',
          quantity: 10,
        })
      ).rejects.toThrow(/Invalid type. Allowed: STOCK_IN, STOCK_OUT, ADJUSTMENT/);
    });

    it('rejects transaction for a product not found in inventory', async () => {
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(null);

      await expect(
        inventoryService.createTransaction(businessId, userId, {
          productId,
          type: 'STOCK_IN',
          quantity: 10,
        })
      ).rejects.toThrow(/Product not found in inventory/);

      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });
  });

  describe('2. Stock Movement Rules', () => {
    it('STOCK_IN increases inventory level accurately', async () => {
      // Current stock is 15
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(15);
      jest.spyOn(inventoryRepo, 'updateQuantity').mockResolvedValue();
      jest.spyOn(inventoryRepo, 'createTransaction').mockImplementation(async (data) => data);

      const result = await inventoryService.createTransaction(businessId, userId, {
        productId,
        type: 'STOCK_IN',
        quantity: 10,
        note: 'Supplier shipment',
      });

      expect(inventoryRepo.updateQuantity).toHaveBeenCalledWith(productId, 25, businessId, mockClient);
      expect(result.quantityBefore).toBe(15);
      expect(result.quantityAfter).toBe(25);
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
    });

    it('STOCK_OUT decreases inventory level accurately', async () => {
      // Current stock is 20
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(20);
      jest.spyOn(inventoryRepo, 'updateQuantity').mockResolvedValue();
      jest.spyOn(inventoryRepo, 'createTransaction').mockImplementation(async (data) => data);

      const result = await inventoryService.createTransaction(businessId, userId, {
        productId,
        type: 'STOCK_OUT',
        quantity: 5,
      });

      expect(inventoryRepo.updateQuantity).toHaveBeenCalledWith(productId, 15, businessId, mockClient);
      expect(result.quantityBefore).toBe(20);
      expect(result.quantityAfter).toBe(15);
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
    });

    it('blocks STOCK_OUT that would result in negative stock', async () => {
      // Current stock is 5
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(5);

      // Attempt to take out 8 units
      await expect(
        inventoryService.createTransaction(businessId, userId, {
          productId,
          type: 'STOCK_OUT',
          quantity: 8,
        })
      ).rejects.toThrow(/Insufficient stock. Available: 5, Requested: 8/);

      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
      expect(mockClient.release).toHaveBeenCalled();
    });

    it('ADJUSTMENT sets exact physical count', async () => {
      // Current stock is 10
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(10);
      jest.spyOn(inventoryRepo, 'updateQuantity').mockResolvedValue();
      jest.spyOn(inventoryRepo, 'createTransaction').mockImplementation(async (data) => data);

      // Physical audit counted 12
      const result = await inventoryService.createTransaction(businessId, userId, {
        productId,
        type: 'ADJUSTMENT',
        quantity: 12,
        note: 'Physical count adjustment',
      });

      expect(inventoryRepo.updateQuantity).toHaveBeenCalledWith(productId, 12, businessId, mockClient);
      expect(result.quantityAfter).toBe(12);
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
    });
  });
});
