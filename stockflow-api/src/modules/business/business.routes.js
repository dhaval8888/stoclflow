const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { authorize, ROLES } = require('../../middleware/authorize');
const { getBusiness, updateBusiness } = require('./business.controller');

router.use(authenticate);

router.get('/',   getBusiness);
router.patch('/', authorize(ROLES.OWNER), updateBusiness);

module.exports = router;
