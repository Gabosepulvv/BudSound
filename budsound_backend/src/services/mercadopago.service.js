const env = require('../config/env');

const credencialesListas = () =>
  Boolean(env.mercadopago.accessToken) && !env.mercadopago.accessToken.includes('PLACEHOLDER');

// El monto es una propina/incentivo al DJ, nunca el precio de una canción
// específica (ver CLAUDE.md, sección "Decisión legal").
//
// IMPORTANTE — flujo real pendiente de rediseño (ver CLAUDE.md, riesgo
// "Autorización de pago vs. captura"): con MercadoPago el pago NO se cobra
// al crear la solicitud. El diseño correcto es:
//   1. Al crear la solicitud (si tiene propina) -> AUTORIZAR el pago
//      (crear el pago con captura diferida). Esto retiene el dinero sin
//      cobrarlo todavía.
//   2. DJ acepta -> CAPTURAR esa autorización (recién ahí se cobra).
//   3. DJ rechaza -> CANCELAR la autorización (se libera, nunca se cobra).
//   4. La autorización expira sola a los 7 días -> necesitamos un cron que
//      cancele/capture solicitudes colgadas antes de ese plazo.
//   5. Solo captura completa para el MVP (la parcial no funciona con todos
//      los medios de pago).
//   6. Split de pagos: el DJ recibe directo a su propia cuenta de
//      MercadoPago (menos la comisión), BudSound nunca concentra el dinero
//      (Opción A del riesgo "¿A quién le llega la plata primero?").
//
// Esta función (`crearPreferenciaDePago`) es un stub temporal que simula
// solo el resultado final para poder demostrar el flujo del MVP mientras
// no hay credenciales de sandbox. Cuando lleguen, reemplazar por
// `autorizarPago` / `capturarPago` / `cancelarAutorizacion` reales usando
// MERCADOPAGO_ACCESS_TOKEN / MERCADOPAGO_PUBLIC_KEY, y mover el punto en
// que se autoriza el pago desde "DJ acepta" hacia "se crea la solicitud".
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
