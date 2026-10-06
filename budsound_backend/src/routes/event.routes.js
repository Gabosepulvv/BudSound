const { Router } = require('express');
const eventController = require('../controllers/event.controller');
const requestController = require('../controllers/request.controller');
const {
  requireAuth,
  requireAuthOrCheckoutScope,
  requireRole,
} = require('../middleware/auth.middleware');

const router = Router();

router.post('/', requireAuth, requireRole('DJ'), eventController.crear);
router.get('/mine', requireAuth, requireRole('DJ'), eventController.misEventos);
router.get('/code/:code', requireAuth, eventController.buscarPorCodigo);
router.patch('/:id/close', requireAuth, requireRole('DJ'), eventController.cerrar);
router.get('/:id/summary', requireAuth, requireRole('DJ'), eventController.resumen);

router.post(
  '/:eventId/requests',
  requireAuthOrCheckoutScope,
  requireRole('PARTICIPANTE'),
  requestController.crear,
);
router.post(
  '/:eventId/checkout-token',
  requireAuth,
  requireRole('PARTICIPANTE'),
  requestController.emitirTokenCheckout,
);
router.get('/:eventId/requests', requireAuth, requireRole('DJ'), requestController.listarPorEvento);
router.get(
  '/:eventId/requests/mine',
  requireAuth,
  requireRole('PARTICIPANTE'),
  requestController.misSolicitudesEnEvento,
);

module.exports = router;
