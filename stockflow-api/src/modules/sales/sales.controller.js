const catchAsync = require('../../utils/catchAsync');
const salesService = require('./sales.service');
const { z } = require('zod');

const saleItemSchema = z.object({
  productId: z.string().uuid(),
  quantity:  z.coerce.number().positive('Quantity must be positive'),
  discount:  z.coerce.number().min(0).default(0),
});

const createSaleSchema = z.object({
  items:          z.array(saleItemSchema).min(1, 'Cart cannot be empty'),
  paymentMethod:  z.enum(['CASH', 'CARD', 'UPI', 'OTHER']).default('CASH'),
  discountAmount: z.coerce.number().min(0).default(0),
  taxAmount:      z.coerce.number().min(0).default(0),
  note:           z.string().max(500).optional(),
});

const listSales = catchAsync(async (req, res) => {
  const result = await salesService.listSales(
    req.user.businessId, req.user.id, req.user.roleName, req.query
  );
  res.json({ success: true, data: result });
});

const getSaleById = catchAsync(async (req, res) => {
  const sale = await salesService.getSaleById(
    req.user.businessId, req.params.id, req.user.id, req.user.roleName
  );
  res.json({ success: true, data: { sale } });
});

const getReceipt = catchAsync(async (req, res) => {
  const receipt = await salesService.getReceipt(
    req.user.businessId, req.params.id, req.user.id, req.user.roleName
  );
  res.json({ success: true, data: { receipt } });
});

const createSale = catchAsync(async (req, res) => {
  const data = createSaleSchema.parse(req.body);
  const result = await salesService.createSale(req.user.businessId, req.user.id, data);
  res.status(201).json({ success: true, message: 'Sale completed', data: result });
});

const voidSale = catchAsync(async (req, res) => {
  const sale = await salesService.voidSale(req.user.businessId, req.params.id, req.user.id);
  res.json({ success: true, message: 'Sale voided and inventory restored', data: { sale } });
});

module.exports = { listSales, getSaleById, getReceipt, createSale, voidSale };
