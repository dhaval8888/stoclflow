const catchAsync = require('../../utils/catchAsync');
const notificationsService = require('./notifications.service');
const AppError = require('../../utils/AppError');
const { z } = require('zod');

const tokenSchema = z.object({
  token:    z.string().min(10),
  platform: z.enum(['android', 'ios']).optional(),
});

const registerToken = catchAsync(async (req, res) => {
  const data = tokenSchema.parse(req.body);
  const result = await notificationsService.registerToken(req.user.id, data);
  res.status(201).json({ success: true, message: 'Device token registered', data: result });
});

const removeToken = catchAsync(async (req, res) => {
  const { token } = req.body;
  if (!token) throw new AppError('Token is required', 400);
  const result = await notificationsService.removeToken(req.user.id, token);
  res.json({ success: true, message: 'Device token removed', data: result });
});

module.exports = { registerToken, removeToken };
