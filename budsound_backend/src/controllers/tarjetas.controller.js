const userModel = require('../models/user.model');
const mercadopagoService = require('../services/mercadopago.service');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

// Lista las tarjetas guardadas del Participante (Perfil → "Tarjetas
// guardadas") — básico de higiene de privacidad, MercadoPago no da una
// pantalla propia para esto. Si todavía no tiene un Customer (nunca pagó,
// o pagó antes de que esta función existiera), la lista queda vacía en vez
// de error.
const listar = asyncHandler(async (req, res) => {
  if (!mercadopagoService.credencialesListas()) return res.json({ tarjetas: [] });

  const customerId = await userModel.obtenerMpCustomerId(req.user.sub);
  if (!customerId) return res.json({ tarjetas: [] });

  const tarjetas = await mercadopagoService.listarTarjetasGuardadas(customerId);
  res.json({
    tarjetas: tarjetas.map((t) => ({
      id: t.id,
      ultimosDigitos: t.last_four_digits,
      franquicia: t.payment_method?.name || t.payment_method?.id || null,
      vencimiento: `${String(t.expiration_month).padStart(2, '0')}/${t.expiration_year}`,
    })),
  });
});

const borrar = asyncHandler(async (req, res) => {
  if (!mercadopagoService.credencialesListas()) {
    throw new ApiError(404, 'No tienes tarjetas guardadas.');
  }
  const customerId = await userModel.obtenerMpCustomerId(req.user.sub);
  if (!customerId) throw new ApiError(404, 'No tienes tarjetas guardadas.');

  await mercadopagoService.borrarTarjetaGuardada(customerId, req.params.cardId);
  res.json({ ok: true });
});

module.exports = { listar, borrar };
