const { Router } = require('express');
const rateLimit = require('express-rate-limit');
const authController = require('../controllers/auth.controller');
const { requireAuth } = require('../middleware/auth.middleware');

const router = Router();

// Limita intentos de login/registro por IP para dificultar fuerza bruta.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Demasiados intentos, espera unos minutos.' },
});

router.post('/register', authLimiter, authController.registrar);
router.post('/login', authLimiter, authController.iniciarSesion);
router.post('/google', authLimiter, authController.google);
router.get('/me', requireAuth, authController.perfil);
router.patch('/me', requireAuth, authController.actualizarPerfil);

module.exports = router;
