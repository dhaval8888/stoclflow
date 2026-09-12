const catchAsync = require('../../utils/catchAsync');
const AppError = require('../../utils/AppError');
const authService = require('./auth.service');
const { z } = require('zod');

const registerSchema = z.object({
  businessName:    z.string().min(2).max(255),
  businessAddress: z.string().max(500).optional(),
  businessPhone:   z.string().max(50).optional(),
  fullName:        z.string().min(2).max(255),
  email:           z.string().email(),
  password:        z.string().min(8, 'Password must be at least 8 characters').max(100),
  currency:        z.string().max(10).optional(),
  timezone:        z.string().max(100).optional(),
});

const loginSchema = z.object({
  email:    z.string().email(),
  password: z.string().min(1, 'Password is required'),
});

const register = catchAsync(async (req, res) => {
  const data = registerSchema.parse(req.body);
  const result = await authService.register(data);

  res.status(201).json({
    success: true,
    message: 'Business account created successfully',
    data:    result,
  });
});

const login = catchAsync(async (req, res) => {
  const data = loginSchema.parse(req.body);
  const result = await authService.login(data);

  res.status(200).json({
    success: true,
    message: 'Login successful',
    data:    result,
  });
});

const refresh = catchAsync(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) throw new AppError('Refresh token is required', 400);

  const result = await authService.refreshToken(refreshToken);

  res.status(200).json({
    success: true,
    data:    result,
  });
});

const logout = catchAsync(async (req, res) => {
  const { refreshToken } = req.body;
  await authService.logout(refreshToken);

  res.status(200).json({
    success: true,
    message: 'Logged out successfully',
  });
});

const getMe = catchAsync(async (req, res) => {
  const profile = await authService.getProfile(req.user.id);

  res.status(200).json({
    success: true,
    data:    { profile },
  });
});

module.exports = { register, login, refresh, logout, getMe };
