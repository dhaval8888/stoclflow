const { v4: uuidv4 } = require('uuid');
const { sendMulticastNotification } = require('../../config/firebase');
const notificationsRepo = require('./notifications.repository');

const OWNER_MANAGER_ROLE_IDS = [1, 2]; // matches seeded roles table

const registerToken = async (userId, { token, platform }) => {
  await notificationsRepo.upsertToken({ id: uuidv4(), userId, token, platform });
  return { registered: true };
};

const removeToken = async (userId, token) => {
  await notificationsRepo.deleteToken(userId, token);
  return { removed: true };
};

const sendLowStockAlert = async (businessId, productName, currentQty) => {
  const tokens = await notificationsRepo.findTokensByBusiness(businessId, OWNER_MANAGER_ROLE_IDS);
  if (!tokens.length) return null;

  return sendMulticastNotification(
    tokens,
    '⚠️ Low Stock Alert',
    `${productName} is running low. Only ${currentQty} units remaining.`,
    { type: 'LOW_STOCK', productName, currentQty: String(currentQty) }
  );
};

module.exports = { registerToken, removeToken, sendLowStockAlert };
