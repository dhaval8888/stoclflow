const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { registerToken, removeToken } = require('./notifications.controller');

router.use(authenticate);

router.post('/token',   registerToken);
router.delete('/token', removeToken);

module.exports = router;
