const analyticsRepo = require('./analytics.repository');

const VALID_PERIODS = ['daily', 'weekly', 'monthly'];

const getSummary = async (businessId) => {
  return analyticsRepo.getSummary(businessId);
};

const getSalesTrend = async (businessId, query) => {
  const days = Math.min(90, Math.max(7, parseInt(query.days, 10) || 30));
  const trend = await analyticsRepo.getSalesTrend(businessId, days);
  return { days, trend };
};

const getTopProducts = async (businessId, query) => {
  const days  = parseInt(query.days, 10) || 30;
  const limit = Math.min(20, Math.max(5, parseInt(query.limit, 10) || 10));
  const products = await analyticsRepo.getTopProducts(businessId, days, limit);
  return { days, limit, products };
};

const getSlowProducts = async (businessId, query) => {
  const days = Math.min(90, Math.max(7, parseInt(query.days, 10) || 30));
  const products = await analyticsRepo.getSlowProducts(businessId, days);
  return { days, count: products.length, products };
};

const getInventoryValue = async (businessId) => {
  return analyticsRepo.getInventoryValue(businessId);
};

const getProfitReport = async (businessId, query) => {
  const days = Math.min(365, Math.max(7, parseInt(query.days, 10) || 30));
  const profit = await analyticsRepo.getProfitReport(businessId, days);
  return { days, ...profit };
};

const getReportByPeriod = async (businessId, query) => {
  const period = VALID_PERIODS.includes(query.period) ? query.period : 'daily';
  const report = await analyticsRepo.getReportByPeriod(businessId, period);
  return { period, report };
};

module.exports = {
  getSummary, getSalesTrend, getTopProducts, getSlowProducts,
  getInventoryValue, getProfitReport, getReportByPeriod,
};
