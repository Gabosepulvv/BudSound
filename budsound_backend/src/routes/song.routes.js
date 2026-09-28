const { Router } = require('express');
const songController = require('../controllers/song.controller');
const { requireAuth } = require('../middleware/auth.middleware');

const router = Router();

router.get('/search', requireAuth, songController.buscar);

module.exports = router;
