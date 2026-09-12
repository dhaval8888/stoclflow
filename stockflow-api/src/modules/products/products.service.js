const { pool } = require('../../config/db');
const { v4: uuidv4 } = require('uuid');
const cloudinary = require('../../config/cloudinary');
const AppError = require('../../utils/AppError');
const { getPagination, buildMeta } = require('../../utils/pagination');
const productsRepo = require('./products.repository');

const sanitizeProduct = (product, roleName) => {
  if (!product) return product;
  if (roleName === 'CASHIER') {
    const { cost_price, ...rest } = product;
    return rest;
  }
  return product;
};

const listProducts = async (businessId, query, roleName) => {
  const { page, limit, offset } = getPagination(query);
  const { search, categoryId, stockStatus, isActive } = query;

  const filters = { search, categoryId, stockStatus, isActive };

  const [total, products] = await Promise.all([
    productsRepo.count(businessId, filters),
    productsRepo.findAll(businessId, filters, limit, offset),
  ]);

  // Attach images
  const ids = products.map((p) => p.id);
  const images = ids.length ? await productsRepo.findImagesByProductIds(ids) : [];
  const imageMap = {};
  for (const img of images) {
    if (!imageMap[img.product_id]) imageMap[img.product_id] = [];
    imageMap[img.product_id].push(img);
  }

  const sanitized = products.map((p) =>
    sanitizeProduct({ ...p, images: imageMap[p.id] || [] }, roleName)
  );

  return {
    products: sanitized,
    meta:     buildMeta(total, page, limit),
  };
};

const getProductById = async (businessId, productId, roleName) => {
  const product = await productsRepo.findById(businessId, productId);
  if (!product) throw new AppError('Product not found', 404);
  product.images = await productsRepo.findImages(productId);
  return sanitizeProduct(product, roleName);
};

const getByBarcode = async (businessId, barcode, roleName) => {
  const product = await productsRepo.findByBarcode(businessId, barcode);
  if (!product) throw new AppError('No product found for this barcode', 404);
  product.images = await productsRepo.findImages(product.id);
  return sanitizeProduct(product, roleName);
};

const getBySku = async (businessId, sku, roleName) => {
  const product = await productsRepo.findBySku(businessId, sku);
  if (!product) throw new AppError('No product found for this SKU', 404);
  product.images = await productsRepo.findImages(product.id);
  return sanitizeProduct(product, roleName);
};

const createProduct = async (businessId, data, userId = null) => {
  const { initialStock = 0, ...productFields } = data;
  if (productFields.sku && await productsRepo.skuExists(businessId, productFields.sku)) {
    throw new AppError(`SKU '${productFields.sku}' already exists for another product`, 409);
  }
  if (productFields.barcode && await productsRepo.barcodeExists(businessId, productFields.barcode)) {
    throw new AppError(`Barcode '${productFields.barcode}' already exists for another product`, 409);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const id = uuidv4();
    const product = await productsRepo.create({ id, businessId, ...productFields }, client);
    await productsRepo.createInventoryRow(id, businessId, initialStock, client);

    if (initialStock > 0) {
      await client.query(
        `INSERT INTO inventory_transactions
           (id, business_id, product_id, user_id, type, quantity, quantity_before, quantity_after, note)
         VALUES ($1, $2, $3, $4, 'STOCK_IN', $5, 0, $5, 'Initial stock on product creation')`,
        [uuidv4(), businessId, id, userId, initialStock]
      );
    }

    await client.query('COMMIT');
    return product;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const updateProduct = async (businessId, productId, data) => {
  if (data.sku && await productsRepo.skuExists(businessId, data.sku, productId)) {
    throw new AppError(`SKU '${data.sku}' already exists`, 409);
  }
  if (data.barcode && await productsRepo.barcodeExists(businessId, data.barcode, productId)) {
    throw new AppError(`Barcode '${data.barcode}' already exists`, 409);
  }

  const product = await productsRepo.update(productId, businessId, data);
  if (!product) throw new AppError('Product not found', 404);
  return product;
};

const softDeleteProduct = async (businessId, productId) => {
  const result = await productsRepo.softDelete(productId, businessId);
  if (!result) throw new AppError('Product not found', 404);
  return result;
};

const addImage = async (businessId, productId, { cloudinaryId, url }) => {
  const product = await productsRepo.findById(businessId, productId);
  if (!product) throw new AppError('Product not found', 404);

  const isPrimary = !(await productsRepo.hasPrimaryImage(productId));
  return productsRepo.createImage({ id: uuidv4(), productId, cloudinaryId, url, isPrimary });
};

const removeImage = async (businessId, productId, imageId) => {
  const image = await productsRepo.findImageById(imageId, productId, businessId);
  if (!image) throw new AppError('Image not found', 404);

  try { await cloudinary.uploader.destroy(image.cloudinary_id); } catch (_) {}

  await productsRepo.deleteImage(imageId);

  if (image.is_primary) {
    await productsRepo.promotePrimaryImage(productId);
  }

  return { deleted: true };
};

module.exports = {
  listProducts, getProductById, getByBarcode, getBySku,
  createProduct, updateProduct, softDeleteProduct,
  addImage, removeImage,
};
