const requestModel = require('../models/request.model');
const eventModel = require('../models/event.model');
const transactionModel = require('../models/transaction.model');
const mercadopagoService = require('../services/mercadopago.service');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

async function cargarPropiaSolicitud(req) {
  const request = await requestModel.buscarPorId(req.params.id);
  if (!request) throw new ApiError(404, 'Solicitud no encontrada.');
  if (request.participante_id !== req.user.sub) {
    throw new ApiError(403, 'No puedes ver el pago de una solicitud que no es tuya.');
  }
  return request;
}

const estado = asyncHandler(async (req, res) => {
  const request = await cargarPropiaSolicitud(req);
  const transaction = await transactionModel.buscarPorRequestId(request.id);
  res.json({ request, transaction });
});

// Solo disponible mientras no existan credenciales reales de MercadoPago:
// permite demostrar el flujo completo (aceptar -> pagar -> aprobado) sin
// depender del gateway real. Cuando lleguen las credenciales, este endpoint
// debe eliminarse y el webhook real (abajo) pasa a ser la única vía.
const simularAprobacion = asyncHandler(async (req, res) => {
  if (mercadopagoService.credencialesListas()) {
    throw new ApiError(409, 'MercadoPago ya está configurado; usa el webhook real.');
  }

  const request = await cargarPropiaSolicitud(req);
  const transaction = await transactionModel.buscarPorRequestId(request.id);
  if (!transaction) throw new ApiError(404, 'Esta solicitud no tiene un pago asociado.');

  const actualizada = await transactionModel.actualizarStatus(
    transaction.id,
    'APROBADA',
    `SIMULADO-PAGO-${transaction.id}`,
  );

  req.io.to(`event:${request.event_id}`).emit('payment:approved', {
    requestId: request.id,
    transaction: actualizada,
  });

  res.json({ transaction: actualizada });
});

// Receptor del webhook real de MercadoPago. Mercado Pago espera 200 aunque
// la notificación no se pueda procesar (para no reintentar indefinidamente).
//
// TODO(equipo): cuando existan credenciales, validar la notificación contra
// la API de MercadoPago (GET /v1/payments/:id) antes de confiar en el body,
// mapear external_reference -> transactions.id, y actualizar status según
// el estado real del pago (approved/rejected/pending).
const webhook = asyncHandler(async (req, res) => {
  console.log('Webhook de MercadoPago recibido (integración pendiente):', req.body);
  res.sendStatus(200);
});

module.exports = { estado, simularAprobacion, webhook };
