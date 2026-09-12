const catchAsync = require('../../utils/catchAsync');
const analyticsService = require('./analytics.service');
const AppError = require('../../utils/AppError');

const getSummary = catchAsync(async (req, res) => {
  const data = await analyticsService.getSummary(req.user.businessId);
  res.json({ success: true, data });
});

const getSalesTrend = catchAsync(async (req, res) => {
  const data = await analyticsService.getSalesTrend(req.user.businessId, req.query);
  res.json({ success: true, data });
});

const getTopProducts = catchAsync(async (req, res) => {
  const data = await analyticsService.getTopProducts(req.user.businessId, req.query);
  res.json({ success: true, data });
});

const getSlowProducts = catchAsync(async (req, res) => {
  const data = await analyticsService.getSlowProducts(req.user.businessId, req.query);
  res.json({ success: true, data });
});

const getInventoryValue = catchAsync(async (req, res) => {
  const data = await analyticsService.getInventoryValue(req.user.businessId);
  res.json({ success: true, data });
});

const getProfitReport = catchAsync(async (req, res) => {
  const data = await analyticsService.getProfitReport(req.user.businessId, req.query);
  res.json({ success: true, data });
});

const getReportByPeriod = catchAsync(async (req, res) => {
  const validPeriods = ['daily', 'weekly', 'monthly'];
  const period = req.query.period;
  if (period && !validPeriods.includes(period)) {
    throw new AppError(`Invalid period. Use: ${validPeriods.join(', ')}`, 400);
  }
  const data = await analyticsService.getReportByPeriod(req.user.businessId, req.query);
  res.json({ success: true, data });
});

module.exports = {
  getSummary, getSalesTrend, getTopProducts, getSlowProducts,
  getInventoryValue, getProfitReport, getReportByPeriod,
};
