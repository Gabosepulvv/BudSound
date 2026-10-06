const env = require('../config/env');

const MP_API = 'https://api.mercadopago.com';

const credencialesListas = () =>
  Boolean(env.mercadopago.accessToken) && !env.mercadopago.accessToken.includes('PLACEHOLDER');

async function llamarMp(path, { method = 'GET', body, idempotencyKey, accessToken } = {}) {
  const headers = {
    // `accessToken` permite operar sobre la cuenta de un DJ conectado por
    // OAuth (ver mercadopago-oauth.service.js) en vez de la cuenta central
    // de BudSound — ver `autorizarPago`.
    Authorization: `Bearer ${accessToken || env.mercadopago.accessToken}`,
    'Content-Type': 'application/json',
  };
  if (idempotencyKey) headers['X-Idempotency-Key'] = idempotencyKey;

  const response = await fetch(`${MP_API}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const mensaje =
      data?.message || data?.cause?.[0]?.description || 'MercadoPago rechazó la operación.';
    const error = new Error(mensaje);
    error.mpStatus = response.status;
    error.mpData = data;
    throw error;
  }
  return data;
}

// El monto es una propina/incentivo al DJ, nunca el precio de una canción
// específica (ver CLAUDE.md, sección "Decisión legal").
//
// Autoriza el pago con captura diferida (`capture: false`): MercadoPago
// retiene el monto en la tarjeta del Participante pero todavía no lo cobra.
// Se llama al crear la solicitud (no al aceptarla) — ver CLAUDE.md, riesgo
// "Autorización de pago vs. captura". Recién se cobra con `capturarPago`
// cuando el DJ acepta, o se libera con `cancelarPago` si rechaza, vence el
// plazo, o el evento cierra antes de que responda.
async function autorizarPago({
  requestId,
  montoClp,
  descripcion,
  token,
  paymentMethodId,
  installments,
  payerEmail,
  // Cuando el DJ del evento conectó su propia cuenta (OAuth marketplace):
  // el pago se autoriza directo en SU cuenta (djAccessToken) y
  // `application_fee` es lo que MercadoPago retiene aparte para BudSound.
  // Si cualquiera de los dos falta, se cobra en la cuenta central de
  // BudSound como antes (comportamiento sin split).
  djAccessToken,
  applicationFee,
}) {
  const pago = await llamarMp('/v1/payments', {
    method: 'POST',
    idempotencyKey: `budsound-autorizacion-${requestId}`,
    accessToken: djAccessToken,
    body: {
      transaction_amount: montoClp,
      token,
      description: descripcion,
      installments: installments || 1,
      payment_method_id: paymentMethodId,
      capture: false,
      payer: { email: payerEmail },
      external_reference: requestId,
      ...(djAccessToken && applicationFee ? { application_fee: applicationFee } : {}),
    },
  });

  if (!['authorized', 'approved', 'pending', 'in_process'].includes(pago.status)) {
    const error = new Error(pago.status_detail || 'El pago no pudo autorizarse.');
    error.mpData = pago;
    throw error;
  }

  return pago;
}

// Cobra de verdad una autorización retenida — se llama cuando el DJ acepta
// la solicitud. Solo funciona mientras la autorización no haya expirado
// (vigencia de 7 días en MercadoPago; el cron de BudSound libera las
// solicitudes colgadas mucho antes de ese plazo).
async function capturarPago(paymentId, { djAccessToken } = {}) {
  return llamarMp(`/v1/payments/${paymentId}`, {
    method: 'PUT',
    accessToken: djAccessToken,
    body: { capture: true },
  });
}

// Libera una autorización sin cobrar nada — se llama cuando el DJ rechaza
// la solicitud, o cuando el cron la cancela por quedar colgada.
async function cancelarPago(paymentId, { djAccessToken } = {}) {
  return llamarMp(`/v1/payments/${paymentId}`, {
    method: 'PUT',
    accessToken: djAccessToken,
    body: { status: 'cancelled' },
  });
}

async function obtenerPago(paymentId) {
  return llamarMp(`/v1/payments/${paymentId}`);
}

// Stub temporal que simula solo el resultado final, para poder demostrar el
// flujo del MVP mientras un integrante del equipo no tenga sus propias
// credenciales de sandbox en su `.env` local (ver `credencialesListas`,
// usado en `request.controller.js` para decidir qué camino tomar).
async function crearPreferenciaDePago({ requestId, montoClp, descripcion }) {
  return {
    simulado: true,
    preferenceId: `SIMULADO-${requestId}`,
    initPoint: null,
    montoClp,
    descripcion,
  };
}

module.exports = {
  credencialesListas,
  autorizarPago,
  capturarPago,
  cancelarPago,
  obtenerPago,
  crearPreferenciaDePago,
};
