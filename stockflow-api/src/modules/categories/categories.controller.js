const catchAsync = require('../../utils/catchAsync');
const categoriesService = require('./categories.service');
const { z } = require('zod');

const createSchema = z.object({
  name:        z.string().min(1).max(150),
  description: z.string().max(500).optional(),
  colorHex:    z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Must be a valid hex color').optional(),
});

const updateSchema = createSchema.partial();

const listCategories = catchAsync(async (req, res) => {
  const categories = await categoriesService.listCategories(req.user.businessId);
  res.json({ success: true, data: { categories } });
});

const createCategory = catchAsync(async (req, res) => {
  const data = createSchema.parse(req.body);
  const category = await categoriesService.createCategory(req.user.businessId, data);
  res.status(201).json({ success: true, message: 'Category created', data: { category } });
});

const updateCategory = catchAsync(async (req, res) => {
  const data = updateSchema.parse(req.body);
  const category = await categoriesService.updateCategory(req.user.businessId, req.params.id, data);
  res.json({ success: true, message: 'Category updated', data: { category } });
});

const deleteCategory = catchAsync(async (req, res) => {
  const result = await categoriesService.deleteCategory(req.user.businessId, req.params.id);
  res.json({ success: true, message: 'Category deleted', data: result });
});

module.exports = { listCategories, createCategory, updateCategory, deleteCategory };
