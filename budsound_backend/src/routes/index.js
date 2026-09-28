const { Router } = require('express');
const authRoutes = require('./auth.routes');
const eventRoutes = require('./event.routes');
const requestRoutes = require('./request.routes');
const songRoutes = require('./song.routes');

const router = Router();

router.get('/health', (req, res) => res.json({ ok: true }));
router.use('/auth', authRoutes);
router.use('/events', eventRoutes);
router.use('/requests', requestRoutes);
router.use('/songs', songRoutes);

module.exports = router;
