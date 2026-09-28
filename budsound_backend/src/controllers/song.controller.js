const itunesService = require('../services/itunes.service');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

const buscar = asyncHandler(async (req, res) => {
  const term = (req.query.q || '').trim();
  if (!term) throw new ApiError(400, 'El parámetro de búsqueda "q" es obligatorio.');

  const resultados = await itunesService.buscarCanciones(term);
  res.json({ resultados });
});

module.exports = { buscar };
