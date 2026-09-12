const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { authorize, ROLES } = require('../../middleware/authorize');
const {
  getSummary, getSalesTrend, getTopProducts, getSlowProducts,
  getInventoryValue, getProfitReport, getReportByPeriod,
} = require('./analytics.controller');

router.use(authenticate);
router.use(authorize(ROLES.OWNER, ROLES.MANAGER));

router.get('/summary',         getSummary);
router.get('/sales-trend',     getSalesTrend);      // ?days=30
router.get('/top-products',    getTopProducts);     // ?days=30&limit=10
router.get('/slow-products',   getSlowProducts);    // ?days=30
router.get('/inventory-value', getInventoryValue);
router.get('/profit',          getProfitReport);    // ?days=30
router.get('/report',          getReportByPeriod);  // ?period=daily|weekly|monthly

module.exports = router;
