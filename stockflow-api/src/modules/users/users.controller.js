const catchAsync = require('../../utils/catchAsync');
const usersService = require('./users.service');
const { z } = require('zod');

const createSchema = z.object({
  fullName: z.string().min(2).max(255),
  email:    z.string().email(),
  phone:    z.string().max(50).nullish().transform(v => (v === '' ? null : v)),
  password: z.string().min(8).max(100),
  roleId:   z.coerce.number().int().min(1).max(3).optional(),
  role:     z.string().optional(),
}).refine(data => data.roleId || data.role, {
  message: "Either 'role' or 'roleId' must be provided",
});

const updateSchema = z.object({
  fullName: z.string().min(2).max(255).optional(),
  phone:    z.string().max(50).nullish().transform(v => (v === '' ? null : v)),
  roleId:   z.coerce.number().int().min(1).max(3).optional(),
  role:     z.string().optional(),
  isActive: z.boolean().optional(),
}).partial();

const listUsers = catchAsync(async (req, res) => {
  const result = await usersService.listEmployees(req.user.businessId, req.query);
  res.json({
    success: true,
    data: {
      ...result,
      users: result.employees,
      employees: result.employees,
    },
  });
});

const getUserById = catchAsync(async (req, res) => {
  const user = await usersService.getEmployee(req.user.businessId, req.params.id);
  res.json({ success: true, data: { user, employee: user } });
});

const createUser = catchAsync(async (req, res) => {
  const data = createSchema.parse(req.body);
  const user = await usersService.addEmployee(req.user.businessId, data);
  res.status(201).json({ success: true, message: 'Employee created successfully', data: { user, employee: user } });
});

const updateUser = catchAsync(async (req, res) => {
  const data = updateSchema.parse(req.body);
  const user = await usersService.updateEmployee(req.user.businessId, req.params.id, req.user.id, data);
  res.json({ success: true, message: 'Employee updated successfully', data: { user, employee: user } });
});

const deactivateUser = catchAsync(async (req, res) => {
  const user = await usersService.deactivateEmployee(req.user.businessId, req.params.id, req.user.id);
  res.json({ success: true, message: 'Employee deactivated', data: { user, employee: user } });
});

module.exports = { listUsers, getUserById, createUser, updateUser, deactivateUser };
