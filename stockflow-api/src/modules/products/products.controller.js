const catchAsync = require('../../utils/catchAsync');
const productsService = require('./products.service');
const { uploadSingle } = require('../../middleware/uploadImage');
const { z } = require('zod');
const AppError = require('../../utils/AppError');

const createSchema = z.object({
  name:              z.string().min(1).max(255),
  description:       z.string().max(2000).nullish().transform((v) => (v === '' ? null : v)),
  categoryId:        z.string().uuid().nullish().or(z.literal('').transform(() => null)),
  sku:               z.string().max(100).nullish().transform((v) => (v === '' ? null : v)),
  barcode:           z.string().max(100).nullish().transform((v) => (v === '' ? null : v)),
  unit:              z.enum(['pcs','kg','ltr','gm','ml','box','dozen','pair']).default('pcs'),
  costPrice:         z.coerce.number().min(0),
  sellingPrice:      z.coerce.number().min(0),
  lowStockThreshold: z.coerce.number().int().min(0).default(10),
  initialStock:      z.coerce.number().min(0).default(0).optional(),
});

const updateSchema = createSchema.partial();

const listProducts = catchAsync(async (req, res) => {
  const result = await productsService.listProducts(req.user.businessId, req.query, req.user.roleName);
  res.json({ success: true, data: result });
});

const getProductById = catchAsync(async (req, res) => {
  const product = await productsService.getProductById(req.user.businessId, req.params.id, req.user.roleName);
  res.json({ success: true, data: { product } });
});

const getByBarcode = catchAsync(async (req, res) => {
  const product = await productsService.getByBarcode(req.user.businessId, req.params.code, req.user.roleName);
  res.json({ success: true, data: { product } });
});

const getBySku = catchAsync(async (req, res) => {
  const product = await productsService.getBySku(req.user.businessId, req.params.sku, req.user.roleName);
  res.json({ success: true, data: { product } });
});

const createProduct = catchAsync(async (req, res) => {
  const data = createSchema.parse(req.body);
  const product = await productsService.createProduct(req.user.businessId, data, req.user.id);
  res.status(201).json({ success: true, message: 'Product created', data: { product } });
});

const updateProduct = catchAsync(async (req, res) => {
  const data = updateSchema.parse(req.body);
  const product = await productsService.updateProduct(req.user.businessId, req.params.id, data);
  res.json({ success: true, message: 'Product updated', data: { product } });
});

const deleteProduct = catchAsync(async (req, res) => {
  const result = await productsService.softDeleteProduct(req.user.businessId, req.params.id);
  res.json({ success: true, message: 'Product deactivated', data: result });
});

const uploadImage = [
  uploadSingle,
  catchAsync(async (req, res) => {
    if (!req.file) throw new AppError('Image file is required', 400);
    const image = await productsService.addImage(req.user.businessId, req.params.id, {
      cloudinaryId: req.file.filename,
      url:          req.file.path,
    });
    res.status(201).json({ success: true, message: 'Image uploaded', data: { image } });
  }),
];

const removeImage = catchAsync(async (req, res) => {
  const result = await productsService.removeImage(req.user.businessId, req.params.id, req.params.imageId);
  res.json({ success: true, message: 'Image removed', data: result });
});

module.exports = {
  listProducts, getProductById, getByBarcode, getBySku,
  createProduct, updateProduct, deleteProduct,
  uploadImage, removeImage,
};
