const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { authorize, ROLES } = require('../../middleware/authorize');
const { listSales, getSaleById, getReceipt, createSale, voidSale } = require('./sales.controller');

router.use(authenticate);

router.post('/',             createSale);
router.get('/',              listSales);
router.get('/:id',           getSaleById);
router.get('/:id/receipt',   getReceipt);                                       // all roles (scoped by cashier)
router.post('/:id/void',     authorize(ROLES.OWNER, ROLES.MANAGER), voidSale);

module.exports = router;
