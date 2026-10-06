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

// Receptor del webhook real de MercadoPago. MercadoPago espera 200 aunque
// la notificación no se pueda procesar (para no reintentar indefinidamente)
// — por eso todos los caminos de abajo terminan en sendStatus(200), incluso
// los que no hicieron nada.
//
// No se confía en el body de la notificación (puede venir manipulado): solo
// trae el id del pago, y con eso se pide el estado real a la API de
// MercadoPago antes de actualizar nada.
const webhook = asyncHandler(async (req, res) => {
  const tipo = req.query.type || req.body?.type || req.body?.topic;
  const paymentId = req.query['data.id'] || req.body?.data?.id || req.body?.resource;

  // El webhook no tiene auth (MercadoPago lo llama directo, sin sesión) y
  // nunca se confía en el body (ver comentario más abajo) — pero el id SÍ
  // se usa tal cual para armar la URL que se llama en la API de
  // MercadoPago (`/v1/payments/${paymentId}`, ver mercadopago.service.js).
  // Sin este chequeo, cualquiera podía mandar un "id" con `/` o `..` y
  // hacer que esa llamada golpeara una ruta distinta de la API de
  // MercadoPago usando nuestro access token.
  if (tipo !== 'payment' || !/^\d+$/.test(String(paymentId || '')) || !mercadopagoService.credencialesListas()) {
    return res.sendStatus(200);
  }

  try {
    const pago = await mercadopagoService.obtenerPago(paymentId);
    const transaction = await transactionModel.buscarPorMpPaymentId(String(pago.id));
    if (!transaction) return res.sendStatus(200);

    const nuevoStatus =
      pago.status === 'approved'
        ? 'APROBADA'
        : pago.status === 'authorized'
        ? 'AUTORIZADA'
        : ['cancelled', 'rejected'].includes(pago.status)
        ? 'RECHAZADA'
        : transaction.status;

    if (nuevoStatus !== transaction.status) {
      const actualizada = await transactionModel.actualizarStatus(transaction.id, nuevoStatus);
      const request = await requestModel.buscarPorId(transaction.request_id);
      if (request) {
        req.io
          .to(`event:${request.event_id}`)
          .emit('payment:approved', { requestId: request.id, transaction: actualizada });
      }
    }
  } catch (error) {
    console.error('Error procesando webhook de MercadoPago:', error.message);
  }

  res.sendStatus(200);
});

module.exports = { estado, simularAprobacion, webhook };
