const eventModel = require('../models/event.model');
const { generarCodigoEvento } = require('../utils/eventCode');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

async function generarCodigoUnico() {
  for (let intento = 0; intento < 5; intento += 1) {
    const code = generarCodigoEvento();
    const existente = await eventModel.buscarPorCodigo(code);
    if (!existente) return code;
  }
  throw new ApiError(500, 'No se pudo generar un código de evento único, reintenta.');
}

const crear = asyncHandler(async (req, res) => {
  const { nombre } = req.body;
  if (!nombre?.trim()) throw new ApiError(400, 'El nombre del evento es obligatorio.');

  const code = await generarCodigoUnico();
  const event = await eventModel.crear({ djId: req.user.sub, code, nombre: nombre.trim() });
  res.status(201).json({ event });
});

const misEventos = asyncHandler(async (req, res) => {
  const events = await eventModel.listarPorDj(req.user.sub);
  res.json({ events });
});

const buscarPorCodigo = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorCodigo(req.params.code.toUpperCase());
  if (!event) throw new ApiError(404, 'No existe un evento con ese código.');
  if (event.status !== 'ACTIVO') throw new ApiError(409, 'Este evento ya fue cerrado.');
  res.json({ event });
});

const cerrar = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorId(req.params.id);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const cerrado = await eventModel.cerrar(event.id);
  if (!cerrado) throw new ApiError(409, 'El evento ya estaba cerrado.');

  const resumen = await eventModel.resumenRecaudacion(event.id);

  req.io.to(`event:${event.id}`).emit('event:closed', { eventId: event.id });

  res.json({ event: cerrado, resumen });
});

const resumen = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorId(req.params.id);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const resumenRecaudacion = await eventModel.resumenRecaudacion(event.id);
  res.json({ event, resumen: resumenRecaudacion });
});

module.exports = { crear, misEventos, buscarPorCodigo, cerrar, resumen };
