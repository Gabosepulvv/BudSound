const { Router } = require('express');
const authController = require('../controllers/auth.controller');
const { requireAuth } = require('../middleware/auth.middleware');

const router = Router();

router.post('/register', authController.registrar);
router.post('/login', authController.iniciarSesion);
router.get('/me', requireAuth, authController.perfil);

module.exports = router;
