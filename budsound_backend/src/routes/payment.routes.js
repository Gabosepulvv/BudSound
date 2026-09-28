const { Router } = require('express');
const paymentController = require('../controllers/payment.controller');
const { requireAuth, requireRole } = require('../middleware/auth.middleware');

const router = Router();

router.get('/requests/:id/payment', requireAuth, requireRole('PARTICIPANTE'), paymentController.estado);
router.post(
  '/requests/:id/payment/simulate-approval',
  requireAuth,
  requireRole('PARTICIPANTE'),
  paymentController.simularAprobacion,
);

module.exports = router;
