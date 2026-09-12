const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { authorize, ROLES } = require('../../middleware/authorize');
const { listUsers, getUserById, createUser, updateUser, deactivateUser } = require('./users.controller');

router.use(authenticate);
router.use(authorize(ROLES.OWNER));

router.get('/',         listUsers);
router.post('/',        createUser);
router.get('/:id',      getUserById);
router.patch('/:id',    updateUser);
router.put('/:id',      updateUser);
router.delete('/:id',   deactivateUser);

module.exports = router;
