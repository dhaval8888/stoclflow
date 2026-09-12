const AppError = require('../../utils/AppError');
const businessRepo = require('./business.repository');

const getProfile = async (businessId) => {
  const business = await businessRepo.findById(businessId);
  if (!business) throw new AppError('Business not found', 404);
  return business;
};

const updateProfile = async (businessId, fields) => {
  const business = await businessRepo.update(businessId, fields);
  if (!business) throw new AppError('Business not found', 404);
  return business;
};

const updateLogo = async (businessId, logoUrl) => {
  const result = await businessRepo.updateLogo(businessId, logoUrl);
  if (!result) throw new AppError('Business not found', 404);
  return result;
};

module.exports = { getProfile, updateProfile, updateLogo };
