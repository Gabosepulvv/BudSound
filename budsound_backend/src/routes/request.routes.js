const { Router } = require('express');
const requestController = require('../controllers/request.controller');
const { requireAuth, requireRole } = require('../middleware/auth.middleware');

const router = Router();

router.patch('/:id/accept', requireAuth, requireRole('DJ'), requestController.aceptar);
router.patch('/:id/reject', requireAuth, requireRole('DJ'), requestController.rechazar);

module.exports = router;
