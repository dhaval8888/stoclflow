const express = require('express');
const router = express.Router();
const authenticate = require('../../middleware/auth');
const { authorize, ROLES } = require('../../middleware/authorize');
const { listCategories, createCategory, updateCategory, deleteCategory } = require('./categories.controller');

router.use(authenticate);

router.get('/',      listCategories);
router.post('/',     authorize(ROLES.OWNER, ROLES.MANAGER), createCategory);
router.patch('/:id', authorize(ROLES.OWNER, ROLES.MANAGER), updateCategory);
router.put('/:id',   authorize(ROLES.OWNER, ROLES.MANAGER), updateCategory);
router.delete('/:id', authorize(ROLES.OWNER, ROLES.MANAGER), deleteCategory);

module.exports = router;
