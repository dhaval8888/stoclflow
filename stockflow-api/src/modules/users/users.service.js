const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');
const AppError = require('../../utils/AppError');
const usersRepo = require('./users.repository');
const { getPagination, buildMeta } = require('../../utils/pagination');

// Role name → role_id mapping (matches seeded roles table)
const ROLE_ID = { OWNER: 1, MANAGER: 2, CASHIER: 3 };

const listEmployees = async (businessId, query) => {
  const { page, limit, offset } = getPagination(query);
  const { role, search, isActive } = query;

  const filters = {
    role,
    search,
    isActive: isActive === undefined ? undefined : isActive !== 'false',
    limit,
    offset,
  };

  const { rows, total } = await usersRepo.findAll(businessId, filters);
  return { employees: rows, meta: buildMeta(total, page, limit) };
};

const getEmployee = async (businessId, userId) => {
  const employee = await usersRepo.findById(businessId, userId);
  if (!employee) throw new AppError('Employee not found', 404);
  return employee;
};

const addEmployee = async (businessId, { fullName, email, phone, password, role, roleId }) => {
  let normalizedRole = role;
  if (!normalizedRole && roleId) {
    const roleIdMap = { 1: 'OWNER', 2: 'MANAGER', 3: 'CASHIER' };
    normalizedRole = roleIdMap[roleId];
  }
  normalizedRole = (normalizedRole || 'CASHIER').toUpperCase();

  if (!ROLE_ID[normalizedRole]) throw new AppError(`Invalid role: ${role || roleId}`, 400);
  if (normalizedRole === 'OWNER') throw new AppError('Cannot create another OWNER', 403);

  if (await usersRepo.emailExists(email)) {
    throw new AppError('An account with this email already exists', 409);
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const employee = await usersRepo.create({
    id:           uuidv4(),
    businessId,
    roleId:       ROLE_ID[normalizedRole],
    fullName,
    email,
    phone,
    passwordHash,
  });

  return employee;
};

const updateEmployee = async (businessId, userId, currentUserId, { fullName, phone, role, roleId, isActive }) => {
  // Prevent editing yourself via this endpoint
  if (userId === currentUserId) {
    throw new AppError('Use the profile endpoint to edit your own account', 400);
  }

  const existing = await usersRepo.findById(businessId, userId);
  if (!existing) throw new AppError('Employee not found', 404);
  if (existing.role_name === 'OWNER') throw new AppError('Cannot modify the OWNER account', 403);

  let targetRoleId = roleId;
  if (role) {
    targetRoleId = ROLE_ID[role.toUpperCase()];
    if (!targetRoleId) throw new AppError(`Invalid role: ${role}`, 400);
  }

  const updated = await usersRepo.update(businessId, userId, {
    fullName: fullName ?? null,
    phone:    phone ?? null,
    roleId:   targetRoleId ?? null,
    isActive: isActive ?? null,
  });

  return updated;
};

const deactivateEmployee = async (businessId, userId, currentUserId) => {
  if (userId === currentUserId) throw new AppError('Cannot deactivate your own account', 400);

  const existing = await usersRepo.findById(businessId, userId);
  if (!existing) throw new AppError('Employee not found', 404);
  if (existing.role_name === 'OWNER') throw new AppError('Cannot deactivate the OWNER', 403);

  return usersRepo.deactivate(businessId, userId);
};

module.exports = {
  listEmployees, getEmployee, addEmployee, updateEmployee, deactivateEmployee,
  listUsers: listEmployees,
  getUserById: getEmployee,
  createUser: addEmployee,
  updateUser: updateEmployee,
  deactivateUser: deactivateEmployee,
};
