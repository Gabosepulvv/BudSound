const userModel = require('../models/user.model');
const mercadopagoService = require('./mercadopago.service');

// Resuelve (o crea) el "Customer" de MercadoPago de un Participante — lo
// usan `checkout.controller.js` (para que el Brick le muestre su tarjeta
// guardada) y `request.controller.js` (para guardar la tarjeta nueva
// después de pagar) — centralizado acá para que los dos lean/escriban
// `mp_customer_id` exactamente igual, sin que se desincronicen.
async function asegurarCustomerId(participanteId, email) {
  const existente = await userModel.obtenerMpCustomerId(participanteId);
  if (existente) return existente;

  const customer = await mercadopagoService.buscarOCrearCustomer({ email });
  await userModel.guardarMpCustomerId(participanteId, customer.id);
  return customer.id;
}

module.exports = { asegurarCustomerId };
