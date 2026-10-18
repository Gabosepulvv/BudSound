const { Router } = require('express');
const authRoutes = require('./auth.routes');
const eventRoutes = require('./event.routes');
const requestRoutes = require('./request.routes');
const songRoutes = require('./song.routes');
const paymentRoutes = require('./payment.routes');
const djRoutes = require('./dj.routes');
const paymentController = require('../controllers/payment.controller');
const mercadopagoService = require('../services/mercadopago.service');
const { pool } = require('../config/db');

const router = Router();

router.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, db: 'up' });
  } catch (error) {
    res.status(503).json({ ok: false, db: 'down' });
  }
});

// Le dice a la app si hay credenciales reales de MercadoPago cargadas
// (ver mercadopago.service.js, credencialesListas) — mientras no las haya
// (ej. el build de demo para la primera APK, sin plata real de por medio),
// el Participante salta directo el Card Payment Brick y confirma una
// propina simulada; apenas se carguen credenciales reales, vuelve sola al
// flujo de pago real sin tocar la app.
router.get('/payment-mode', (req, res) => {
  res.json({ pagoReal: mercadopagoService.credencialesListas() });
});

router.use('/auth', authRoutes);
router.use('/events', eventRoutes);
router.use('/requests', requestRoutes);
router.use('/songs', songRoutes);
router.use('/', paymentRoutes);
router.use('/dj', djRoutes);

// Sin auth: MercadoPago llama este endpoint directamente, no un usuario logueado.
router.post('/webhooks/mercadopago', paymentController.webhook);

module.exports = router;
