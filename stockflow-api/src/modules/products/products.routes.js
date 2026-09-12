const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { authorize, ROLES } = require('../../middleware/authorize');
const {
  listProducts, getProductById, getByBarcode, getBySku,
  createProduct, updateProduct, deleteProduct,
  uploadImage, removeImage,
} = require('./products.controller');

router.use(authenticate);

// Lookup endpoints — accessible to all roles
router.get('/barcode/:code', getByBarcode);
router.get('/sku/:sku',      getBySku);

router.get('/',      listProducts);
router.post('/',     authorize(ROLES.OWNER, ROLES.MANAGER), createProduct);
router.get('/:id',   getProductById);
router.patch('/:id', authorize(ROLES.OWNER, ROLES.MANAGER), updateProduct);
router.put('/:id',   authorize(ROLES.OWNER, ROLES.MANAGER), updateProduct);
router.delete('/:id', authorize(ROLES.OWNER, ROLES.MANAGER), deleteProduct);

router.post('/:id/images',           authorize(ROLES.OWNER, ROLES.MANAGER), uploadImage);
router.delete('/:id/images/:imageId', authorize(ROLES.OWNER, ROLES.MANAGER), removeImage);

module.exports = router;
