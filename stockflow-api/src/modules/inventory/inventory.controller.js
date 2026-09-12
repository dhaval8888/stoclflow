const catchAsync = require('../../utils/catchAsync');
const inventoryService = require('./inventory.service');
const { z } = require('zod');

const txSchema = z.object({
  productId: z.string().uuid(),
  type:      z.enum(['STOCK_IN', 'STOCK_OUT', 'ADJUSTMENT']),
  quantity:  z.coerce.number().max(999999).refine((v) => v !== 0, { message: 'Quantity cannot be zero' }),
  note:      z.string().max(500).optional(),
});

const listStock = catchAsync(async (req, res) => {
  const result = await inventoryService.listStock(req.user.businessId, req.query);
  res.json({ success: true, data: result });
});

const getStockByProduct = catchAsync(async (req, res) => {
  const stock = await inventoryService.getStockByProduct(req.user.businessId, req.params.productId);
  res.json({ success: true, data: { stock } });
});

const getLowStock = catchAsync(async (req, res) => {
  const products = await inventoryService.getLowStockProducts(req.user.businessId);
  res.json({ success: true, data: { count: products.length, products } });
});

const getOutOfStock = catchAsync(async (req, res) => {
  const products = await inventoryService.getOutOfStockProducts(req.user.businessId);
  res.json({ success: true, data: { count: products.length, products } });
});

const createTransaction = catchAsync(async (req, res) => {
  const data = txSchema.parse(req.body);
  const transaction = await inventoryService.createTransaction(req.user.businessId, req.user.id, data);
  res.status(201).json({ success: true, message: 'Inventory updated', data: { transaction } });
});

const listTransactions = catchAsync(async (req, res) => {
  const result = await inventoryService.listTransactions(req.user.businessId, req.query);
  res.json({ success: true, data: result });
});

module.exports = {
  listStock, getStockByProduct, getLowStock, getOutOfStock,
  createTransaction, listTransactions,
};
