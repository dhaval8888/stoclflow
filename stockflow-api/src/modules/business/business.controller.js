const catchAsync = require('../../utils/catchAsync');
const businessService = require('./business.service');
const { z } = require('zod');

const updateSchema = z.object({
  name:     z.string().min(2).max(255).optional(),
  address:  z.string().max(500).optional(),
  phone:    z.string().max(50).optional(),
  email:    z.string().email().optional(),
  currency: z.string().max(10).optional(),
  timezone: z.string().max(100).optional(),
}).partial();

const getBusiness = catchAsync(async (req, res) => {
  const business = await businessService.getBusiness(req.user.businessId);
  res.json({ success: true, data: { business } });
});

const updateBusiness = catchAsync(async (req, res) => {
  const data = updateSchema.parse(req.body);
  const business = await businessService.updateBusiness(req.user.businessId, data);
  res.json({ success: true, message: 'Business updated successfully', data: { business } });
});

module.exports = { getBusiness, updateBusiness };
