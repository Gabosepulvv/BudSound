const { Router } = require('express');
const requestController = require('../controllers/request.controller');
const { requireAuth, requireRole } = require('../middleware/auth.middleware');

const router = Router();

router.get(
  '/mine',
  requireAuth,
  requireRole('PARTICIPANTE'),
  requestController.misSolicitudes,
);
router.patch('/:id/accept', requireAuth, requireRole('DJ'), requestController.aceptar);
router.patch('/:id/reject', requireAuth, requireRole('DJ'), requestController.rechazar);
router.patch('/:id/played', requireAuth, requireRole('DJ'), requestController.marcarReproducida);

module.exports = router;
