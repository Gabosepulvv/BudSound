const { Router } = require('express');
const authRoutes = require('./auth.routes');
const eventRoutes = require('./event.routes');
const requestRoutes = require('./request.routes');
const songRoutes = require('./song.routes');
const paymentRoutes = require('./payment.routes');
const paymentController = require('../controllers/payment.controller');
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

router.use('/auth', authRoutes);
router.use('/events', eventRoutes);
router.use('/requests', requestRoutes);
router.use('/songs', songRoutes);
router.use('/', paymentRoutes);

// Sin auth: MercadoPago llama este endpoint directamente, no un usuario logueado.
router.post('/webhooks/mercadopago', paymentController.webhook);

module.exports = router;
