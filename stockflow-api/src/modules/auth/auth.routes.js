const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { register, login, refresh, logout, getMe } = require('./auth.controller');

router.post('/register', register);
router.post('/login',    login);
router.post('/refresh',  refresh);
router.post('/logout',   logout);
router.get('/me',        authenticate, getMe);

module.exports = router;
