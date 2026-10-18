const itunesService = require('../services/itunes.service');
const eventModel = require('../models/event.model');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

// Si viene `eventId`, acota los resultados a los géneros que el DJ declaró
// para ese evento (ver GENEROS_VALIDOS en event.controller.js) — "mejor
// esfuerzo" en el caso de la búsqueda libre (ver itunes.service.js,
// `buscarCancionesPorGeneros`: la Search API no filtra de verdad, se
// filtra lo que ya devolvió). Sin `eventId`, o si el evento no existe o no
// declaró géneros, se comporta exactamente como antes.
async function generosDelEvento(eventId) {
  if (!eventId) return null;
  const event = await eventModel.buscarPorId(eventId);
  return event?.generos?.length ? event.generos : null;
}

const buscar = asyncHandler(async (req, res) => {
  const term = (req.query.q || '').trim();
  if (!term) throw new ApiError(400, 'El parámetro de búsqueda "q" es obligatorio.');

  const generos = await generosDelEvento(req.query.eventId);
  const resultados = generos
    ? await itunesService.buscarCancionesPorGeneros(term, generos)
    : await itunesService.buscarCanciones(term);
  res.json({ resultados });
});

// Canciones populares para que la pantalla de pedir una canción no arranque
// vacía — ver itunes.service.js.
const top = asyncHandler(async (req, res) => {
  const generos = await generosDelEvento(req.query.eventId);
  const resultados = generos
    ? await itunesService.topCancionesPorGeneros(generos)
    : await itunesService.topCanciones();
  res.json({ resultados });
});

module.exports = { buscar, top };
