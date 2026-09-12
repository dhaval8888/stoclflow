const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { authorize, ROLES } = require('../../middleware/authorize');
const {
  listStock, getStockByProduct, getLowStock, getOutOfStock,
  createTransaction, listTransactions,
} = require('./inventory.controller');

router.use(authenticate);
router.use(authorize(ROLES.OWNER, ROLES.MANAGER));

router.get('/',               listStock);
router.get('/low-stock',      getLowStock);
router.get('/out-of-stock',   getOutOfStock);
router.get('/transactions',   listTransactions);
router.get('/transaction',    listTransactions);
router.post('/transaction',   createTransaction);
router.post('/transactions',  createTransaction);
router.get('/:productId',     getStockByProduct);

module.exports = router;
