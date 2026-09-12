const { v4: uuidv4 } = require('uuid');
const AppError = require('../../utils/AppError');
const categoriesRepo = require('./categories.repository');

const listCategories = async (businessId) => {
  return categoriesRepo.findAll(businessId);
};

const createCategory = async (businessId, { name, description, colorHex }) => {
  if (await categoriesRepo.nameExists(businessId, name)) {
    throw new AppError(`Category '${name}' already exists`, 409);
  }
  return categoriesRepo.create({ id: uuidv4(), businessId, name, description, colorHex });
};

const updateCategory = async (businessId, categoryId, { name, description, colorHex }) => {
  if (name && await categoriesRepo.nameExists(businessId, name, categoryId)) {
    throw new AppError(`Category '${name}' already exists`, 409);
  }
  const category = await categoriesRepo.update(businessId, categoryId, { name, description, colorHex });
  if (!category) throw new AppError('Category not found', 404);
  return category;
};

const deleteCategory = async (businessId, categoryId) => {
  const activeCount = await categoriesRepo.countActiveProducts(businessId, categoryId);
  if (activeCount > 0) {
    throw new AppError(
      `Cannot delete category: ${activeCount} active product(s) still reference it. Please reassign or delete these products first.`,
      400
    );
  }
  const result = await categoriesRepo.remove(businessId, categoryId);
  if (!result) throw new AppError('Category not found', 404);
  return result;
};

module.exports = { listCategories, createCategory, updateCategory, deleteCategory };
