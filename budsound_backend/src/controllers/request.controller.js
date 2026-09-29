const requestModel = require('../models/request.model');
const eventModel = require('../models/event.model');
const transactionModel = require('../models/transaction.model');
const mercadopagoService = require('../services/mercadopago.service');
const env = require('../config/env');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

const MONTO_MIN = 500;
const MONTO_MAX = 20000;

const crear = asyncHandler(async (req, res) => {
  const { itunesTrackId, titulo, artista, artworkUrl, montoClp, terminosAceptados } = req.body;
  const event = await eventModel.buscarPorId(req.params.eventId);

  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.status !== 'ACTIVO') throw new ApiError(409, 'Este evento ya fue cerrado.');
  if (!itunesTrackId || !titulo?.trim() || !artista?.trim()) {
    throw new ApiError(400, 'Faltan datos de la canción.');
  }

  const monto = Number(montoClp) || 0;
  if (monto !== 0 && (monto < MONTO_MIN || monto > MONTO_MAX)) {
    throw new ApiError(400, `El monto debe ser entre $${MONTO_MIN} y $${MONTO_MAX} CLP.`);
  }
  // Con propina, el participante debe aceptar explícitamente que no hay
  // devolución una vez que el DJ acepte (ver CLAUDE.md, riesgo "El
  // participante pide la devolución del dinero").
  if (monto > 0 && !terminosAceptados) {
    throw new ApiError(400, 'Debes aceptar los Términos y Condiciones para enviar una propina.');
  }

  const request = await requestModel.crear({
    eventId: event.id,
    participanteId: req.user.sub,
    itunesTrackId,
    titulo: titulo.trim(),
    artista: artista.trim(),
    artworkUrl,
    montoClp: monto,
    terminosAceptados: monto > 0 ? true : Boolean(terminosAceptados),
  });

  req.io.to(`event:${event.id}`).emit('request:created', { request });

  res.status(201).json({ request });
});

const listarPorEvento = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorId(req.params.eventId);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const requests = await requestModel.listarPorEvento(event.id, { status: req.query.status });
  res.json({ requests });
});

const misSolicitudesEnEvento = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorId(req.params.eventId);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');

  const requests = await requestModel.listarPorEventoYParticipante(event.id, req.user.sub);
  res.json({ requests });
});

async function resolverSolicitud(req, res, nuevoStatus) {
  const request = await requestModel.buscarPorId(req.params.id);
  if (!request) throw new ApiError(404, 'Solicitud no encontrada.');

  const event = await eventModel.buscarPorId(request.event_id);
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const resuelta = await requestModel.resolver(request.id, nuevoStatus);
  if (!resuelta) throw new ApiError(409, 'La solicitud ya fue resuelta.');

  let pago = null;
  if (nuevoStatus === 'ACEPTADA' && resuelta.monto_clp > 0) {
    const comisionClp = Math.round(resuelta.monto_clp * env.commissionRate);
    const montoNetoClp = resuelta.monto_clp - comisionClp;

    pago = await mercadopagoService.crearPreferenciaDePago({
      requestId: resuelta.id,
      montoClp: resuelta.monto_clp,
      descripcion: `Propina para ${event.nombre}: ${resuelta.titulo}`,
    });

    const transaction = await transactionModel.crear({
      requestId: resuelta.id,
      montoBrutoClp: resuelta.monto_clp,
      comisionClp,
      montoNetoClp,
      mpPaymentId: pago.preferenceId,
    });

    req.io.to(`event:${event.id}`).emit('request:resolved', { request: resuelta, transaction });
  } else {
    req.io.to(`event:${event.id}`).emit('request:resolved', { request: resuelta });
  }

  res.json({ request: resuelta, pago });
}

const aceptar = asyncHandler((req, res) => resolverSolicitud(req, res, 'ACEPTADA'));
const rechazar = asyncHandler((req, res) => resolverSolicitud(req, res, 'RECHAZADA'));

// Evidencia con timestamp de que la canción sonó — ver CLAUDE.md, riesgo
// "Contracargo": es lo único que se puede aportar como prueba interna si
// MercadoPago abre una disputa por un pago ya capturado.
const marcarReproducida = asyncHandler(async (req, res) => {
  const request = await requestModel.buscarPorId(req.params.id);
  if (!request) throw new ApiError(404, 'Solicitud no encontrada.');

  const event = await eventModel.buscarPorId(request.event_id);
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const actualizada = await requestModel.marcarReproducida(request.id);
  if (!actualizada) {
    throw new ApiError(409, 'Solo se puede marcar como reproducida una solicitud aceptada, una vez.');
  }

  req.io.to(`event:${event.id}`).emit('request:played', { request: actualizada });
  res.json({ request: actualizada });
});

module.exports = {
  crear,
  listarPorEvento,
  misSolicitudesEnEvento,
  aceptar,
  rechazar,
  marcarReproducida,
};
