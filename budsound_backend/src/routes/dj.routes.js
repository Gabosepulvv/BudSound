const { Router } = require('express');
const rateLimit = require('express-rate-limit');
const djMpController = require('../controllers/dj-mercadopago.controller');
const { requireAuth, requireRole } = require('../middleware/auth.middleware');

const router = Router();

const mpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Demasiados intentos, espera unos minutos.' },
});

router.get('/mercadopago/connect', requireAuth, requireRole('DJ'), djMpController.iniciarConexion);
router.get('/mercadopago/callback', mpLimiter, djMpController.callback);
router.get('/mercadopago/status', requireAuth, requireRole('DJ'), djMpController.estado);
router.delete('/mercadopago/connection', requireAuth, requireRole('DJ'), djMpController.desconectar);

module.exports = router;
