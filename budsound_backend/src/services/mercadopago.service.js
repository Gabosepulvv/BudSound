const env = require('../config/env');

const credencialesListas = () =>
  Boolean(env.mercadopago.accessToken) && !env.mercadopago.accessToken.includes('PLACEHOLDER');

// El monto es una propina/incentivo al DJ, nunca el precio de una canción
// específica (ver CLAUDE.md, sección "Decisión legal").
//
// TODO(equipo): cuando lleguen las credenciales de sandbox, reemplazar este
// stub por la integración real con el SDK de MercadoPago (Checkout API o
// Checkout Pro) usando MERCADOPAGO_ACCESS_TOKEN / MERCADOPAGO_PUBLIC_KEY.
async function crearPreferenciaDePago({ requestId, montoClp, descripcion }) {
  if (!credencialesListas()) {
    return {
      simulado: true,
      preferenceId: `SIMULADO-${requestId}`,
      initPoint: null,
      montoClp,
      descripcion,
    };
  }

  throw new Error('Integración real de MercadoPago pendiente de implementar.');
}

module.exports = { crearPreferenciaDePago, credencialesListas };
