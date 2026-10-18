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

// HH:MM o HH:MM:SS — lo que entrega un <input type="time"> / TimeOfDay de
// Flutter formateado a mano, sin segundos.
const FORMATO_HORA = /^([01]\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$/;

// YYYY-MM-DD — lo que entrega un <input type="date"> / DateTime de Flutter
// formateado a mano (ver DateTime.toIso8601String().split('T').first en
// dj_events_screen.dart).
const FORMATO_FECHA = /^\d{4}-\d{2}-\d{2}$/;

// Lista fija (no una tabla aparte): son pocos valores, no cambian seguido,
// y así el frontend puede mostrar chips fijos sin pedirle la lista al
// backend. Si el equipo necesita agregar un género, se edita acá y en
// `dj_events_screen.dart` (`_generosDisponibles`) — deben quedar iguales,
// porque el backend rechaza cualquier valor que no esté en esta lista.
const GENEROS_VALIDOS = [
  'Reggaetón',
  'Pop',
  'Rock',
  'Electrónica',
  'Cumbia',
  'Hip-Hop/Rap',
  'Salsa',
  'Bachata',
  'Techno/House',
  'Indie',
  'Trap',
  'Variado',
];

// ~2.5MB de imagen en base64 pesa ~3.3MB como texto — algo más grande que
// el límite de la foto de perfil (ver AVATAR_MAX_LENGTH en
// auth.controller.js) porque esto es una imagen de evento/flyer, no un
// avatar chico.
const IMAGEN_EVENTO_MAX_LENGTH = 3_500_000;

function validarImagenEvento(imagenDataUrl) {
  if (imagenDataUrl === undefined || imagenDataUrl === null) return;
  if (!/^data:image\/(png|jpe?g|webp);base64,/.test(imagenDataUrl)) {
    throw new ApiError(400, 'La imagen del evento debe ser PNG, JPEG o WEBP.');
  }
  if (imagenDataUrl.length > IMAGEN_EVENTO_MAX_LENGTH) {
    throw new ApiError(400, 'La imagen del evento es muy pesada. Usa una imagen más liviana.');
  }
}

const crear = asyncHandler(async (req, res) => {
  const { nombre, horaInicio, horaFin, fechaInicio, fechaFin, generos, imagenDataUrl } =
    req.body;

  // Un DJ no puede tener dos eventos activos a la vez — evita que alguien
  // abra uno nuevo por error (o desde otro dispositivo) mientras el de
  // verdad sigue recibiendo solicitudes en otra pantalla. Tiene que cerrar
  // el que tiene antes de crear otro.
  const activo = await eventModel.buscarActivoPorDj(req.user.sub);
  if (activo) {
    throw new ApiError(
      409,
      `Ya tienes un evento activo ("${activo.nombre}") — ciérralo antes de crear uno nuevo.`,
    );
  }

  if (!nombre?.trim()) throw new ApiError(400, 'El nombre del evento es obligatorio.');
  if (!horaInicio || !horaFin) {
    throw new ApiError(400, 'Debes indicar la hora de inicio y de término del evento.');
  }
  if (!FORMATO_HORA.test(horaInicio) || !FORMATO_HORA.test(horaFin)) {
    throw new ApiError(400, 'Hora inválida.');
  }
  if (!fechaInicio || !fechaFin) {
    throw new ApiError(400, 'Debes indicar la fecha del evento.');
  }
  if (!FORMATO_FECHA.test(fechaInicio) || !FORMATO_FECHA.test(fechaFin)) {
    throw new ApiError(400, 'Fecha inválida.');
  }
  if (fechaFin < fechaInicio) {
    throw new ApiError(400, 'La fecha de término no puede ser antes que la de inicio.');
  }
  if (!Array.isArray(generos) || generos.length === 0) {
    throw new ApiError(400, 'Elige al menos un género para el evento.');
  }
  if (generos.some((g) => !GENEROS_VALIDOS.includes(g))) {
    throw new ApiError(400, 'Uno de los géneros elegidos no es válido.');
  }
  validarImagenEvento(imagenDataUrl);

  const code = await generarCodigoUnico();
  const event = await eventModel.crear({
    djId: req.user.sub,
    code,
    nombre: nombre.trim(),
    horaInicio,
    horaFin,
    fechaInicio,
    fechaFin,
    generos,
    imagenDataUrl,
  });
  res.status(201).json({ event });
});

// La imagen se puede cambiar o quitar en cualquier momento (evento activo
// o ya cerrado) — a diferencia del nombre artístico (decisión 35), no hay
// ninguna razón para bloquearlo con un evento activo: no es algo que
// confunda a quien ya se unió, es solo una imagen de referencia.
const actualizarImagen = asyncHandler(async (req, res) => {
  const { imagenDataUrl } = req.body;
  validarImagenEvento(imagenDataUrl);

  const event = await eventModel.buscarPorId(req.params.id);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const actualizado = await eventModel.actualizarImagen(event.id, imagenDataUrl ?? null);
  res.json({ event: actualizado });
});

const misEventos = asyncHandler(async (req, res) => {
  const events = await eventModel.listarPorDj(req.user.sub);
  res.json({ events });
});

// Resumen de toda la carrera del DJ (todos sus eventos) — para la sección
// "Tus estadísticas" de Inicio, distinto del resumen de un solo evento
// (`resumen` más abajo).
const resumenGeneral = asyncHandler(async (req, res) => {
  const resumen = await eventModel.resumenGeneralPorDj(req.user.sub);
  res.json({ resumen });
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

module.exports = {
  crear,
  misEventos,
  resumenGeneral,
  buscarPorCodigo,
  actualizarImagen,
  cerrar,
  resumen,
};
