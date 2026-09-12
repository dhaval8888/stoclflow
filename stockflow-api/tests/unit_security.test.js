process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'super_secret_test_key_minimum_32_characters_long_123';

const salesService = require('../src/modules/sales/sales.service');
const salesRepo = require('../src/modules/sales/sales.repository');
const inventoryRepo = require('../src/modules/inventory/inventory.repository');
const inventoryService = require('../src/modules/inventory/inventory.service');
const authService = require('../src/modules/auth/auth.service');
const authRepo = require('../src/modules/auth/auth.repository');
const { pool } = require('../src/config/db');
const { generateRefreshToken, hashToken } = require('../src/utils/tokens');

describe('Security & Consistency Unit Verification', () => {
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

  describe('1. Sale Price Security', () => {
    const businessId = '11111111-1111-1111-1111-111111111111';
    const cashierId  = '22222222-2222-2222-2222-222222222222';
    const productId  = '33333333-3333-3333-3333-333333333333';

    it('strictly enforces DB product price and ignores manipulated client unitPrice', async () => {
      // DB says product price is $500
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productId, name: 'Expensive Item', selling_price: '500.00', is_active: true },
      ]);
      // Inventory has 10 units
      jest.spyOn(inventoryRepo, 'lockMultipleForUpdate').mockResolvedValue({
        [productId]: 10,
      });

      let capturedSaleParams = null;
      jest.spyOn(salesRepo, 'createSale').mockImplementation(async (data) => {
        capturedSaleParams = data;
        return { id: data.id, ...data };
      });
      jest.spyOn(salesRepo, 'createSaleItem').mockResolvedValue({});
      jest.spyOn(inventoryRepo, 'updateQuantity').mockResolvedValue();
      jest.spyOn(inventoryRepo, 'createTransaction').mockResolvedValue({});

      // Attacker sends custom unitPrice: 1.00 instead of 500.00
      const salePayload = {
        items: [{ productId, quantity: 2, unitPrice: 1.00 }],
        paymentMethod: 'CASH',
      };

      const result = await salesService.createSale(businessId, cashierId, salePayload);

      expect(mockClient.query).toHaveBeenCalledWith('BEGIN');
      expect(mockClient.query).toHaveBeenCalledWith('COMMIT');
      // Subtotal MUST be 2 * $500 = $1000, NOT $2.00
      expect(capturedSaleParams.subtotal).toBe(1000.00);
      expect(capturedSaleParams.totalAmount).toBe(1000.00);
    });

    it('rejects client discount that exceeds line item total', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productId, name: 'Item', selling_price: '100.00', is_active: true },
      ]);
      jest.spyOn(inventoryRepo, 'lockMultipleForUpdate').mockResolvedValue({
        [productId]: 10,
      });

      const salePayload = {
        items: [{ productId, quantity: 1, discount: 150.00 }],
      };

      await expect(
        salesService.createSale(businessId, cashierId, salePayload)
      ).rejects.toThrow(/cannot exceed line item total/i);

      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });

    it('rejects sale if stock is insufficient and executes ROLLBACK', async () => {
      jest.spyOn(salesRepo, 'findProductsById').mockResolvedValue([
        { id: productId, name: 'Item', selling_price: '100.00', is_active: true },
      ]);
      // Only 1 item available
      jest.spyOn(inventoryRepo, 'lockMultipleForUpdate').mockResolvedValue({
        [productId]: 1,
      });

      const salePayload = {
        items: [{ productId, quantity: 5 }],
      };

      await expect(
        salesService.createSale(businessId, cashierId, salePayload)
      ).rejects.toThrow(/insufficient stock/i);

      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });
  });

  describe('2. Refresh Token Rotation', () => {
    it('rotates refresh token: invalidates old token and returns fresh pair', async () => {
      const userId = '44444444-4444-4444-4444-444444444444';
      const userPayload = { id: userId, businessId: 'biz-1', roleName: 'OWNER' };

      const oldRefreshToken = generateRefreshToken(userPayload);
      const oldHash = hashToken(oldRefreshToken);

      // Stored token mock
      jest.spyOn(authRepo, 'findRefreshToken').mockResolvedValue({
        id: 'rt-1',
        user_id: userId,
        expires_at: new Date(Date.now() + 3600000), // valid
      });

      const deleteSpy = jest.spyOn(authRepo, 'deleteRefreshToken').mockResolvedValue();
      const storeSpy  = jest.spyOn(authRepo, 'storeRefreshToken').mockResolvedValue();
      jest.spyOn(authRepo, 'pruneUserRefreshTokens').mockResolvedValue();
      jest.spyOn(authRepo, 'findUserById').mockResolvedValue({
        id: userId,
        business_id: 'biz-1',
        role_name: 'OWNER',
        is_active: true,
      });

      const result = await authService.refreshToken(oldRefreshToken);

      // 1. Old token hash was deleted from DB
      expect(deleteSpy).toHaveBeenCalledWith(oldHash);

      // 2. New refresh token was generated and stored
      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();
      expect(result.refreshToken).not.toBe(oldRefreshToken);

      expect(storeSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          userId,
          tokenHash: hashToken(result.refreshToken),
        })
      );
    });

    it('rejects invalid or forged refresh token', async () => {
      await expect(
        authService.refreshToken('forged.invalid.token')
      ).rejects.toThrow(/invalid or expired refresh token/i);
    });
  });

  describe('3. Inventory Business Consistency', () => {
    it('rejects stock deduction if quantity drops below zero', async () => {
      const businessId = 'biz-1';
      const userId = 'user-1';
      const productId = 'prod-1';

      // Current stock is 5
      jest.spyOn(inventoryRepo, 'lockForUpdate').mockResolvedValue(5);

      // Request deduction of 10
      await expect(
        inventoryService.createTransaction(businessId, userId, {
          productId,
          type: 'STOCK_OUT',
          quantity: 10,
        })
      ).rejects.toThrow(/insufficient stock/i);

      expect(mockClient.query).toHaveBeenCalledWith('ROLLBACK');
    });
  });
});
