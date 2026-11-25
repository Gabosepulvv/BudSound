const env = require('../config/env');
const debugStream = require('./debug-stream.service');

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
  issuerId,
  identificationType,
  identificationNumber,
  payerEmail,
  // Cuando el token viene de una tarjeta YA guardada (ver
  // mp-customer.helper.js y checkout.controller.js, formulario de "pagar
  // con tarjeta guardada"), el `payer` va con `type`+`id` del Customer en
  // vez de email/identification — así lo exige la propia API de
  // MercadoPago para pagos con tarjeta guardada (ver DECISIONES_TECNICAS.md
  // #45, "Receive payments with saved cards").
  customerId,
  // Cuando el DJ del evento conectó su propia cuenta (OAuth marketplace):
  // el pago se autoriza directo en SU cuenta (djAccessToken) y
  // `application_fee` es lo que MercadoPago retiene aparte para BudSound.
  // Si cualquiera de los dos falta, se cobra en la cuenta central de
  // BudSound como antes (comportamiento sin split).
  djAccessToken,
  applicationFee,
}) {
  const body = {
    transaction_amount: montoClp,
    token,
    description: descripcion,
    installments: installments || 1,
    payment_method_id: paymentMethodId,
    capture: false,
    payer: customerId
      ? { type: 'customer', id: customerId }
      : {
          email: payerEmail,
          ...(identificationType && identificationNumber
            ? { identification: { type: identificationType, number: identificationNumber } }
            : {}),
        },
    external_reference: requestId,
    // Varios bancos comparten el mismo rango de tarjetas (BIN); sin
    // esto MercadoPago puede rechazar el pago con "Params Error" al no
    // poder resolver solo a qué emisor pertenece.
    ...(issuerId ? { issuer_id: issuerId } : {}),
    ...(djAccessToken && applicationFee ? { application_fee: applicationFee } : {}),
  };
  // MercadoPago devuelve "Params Error" sin decir qué parámetro falló (ver
  // `llamarMp`, que ya loguea esa respuesta) — sin esto, no hay forma de
  // comparar qué mandamos de verdad contra qué pide. `token` se enmascara
  // porque es de un solo uso, pero igual es un dato de la tarjeta.
  const bodyParaLog = { ...body, token: token ? `${token.slice(0, 6)}…` : token };
  console.log('Body enviado a MercadoPago (/v1/payments):', JSON.stringify(bodyParaLog, null, 2));
  debugStream.emitir('mp_request', bodyParaLog);
  const pago = await llamarMp('/v1/payments', {
    method: 'POST',
    idempotencyKey: `budsound-autorizacion-${requestId}`,
    accessToken: djAccessToken,
    body,
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

// Busca o crea el "Customer" de MercadoPago del Participante (ver
// schema.sql, mp_customer_id) — SIEMPRE contra la cuenta CENTRAL de
// BudSound (nunca `djAccessToken`): el Card Payment Brick tokeniza con la
// Public Key central sin importar si el pago después se autoriza en la
// cuenta de un DJ conectado, así que un solo Customer alcanza para pagarle
// a cualquier DJ — ver DECISIONES_TECNICAS.md. Se busca primero por email
// porque MercadoPago no deja crear dos Customers con el mismo correo (tira
// error si ya existe), y es más simple buscar que parsear ese error.
async function buscarOCrearCustomer({ email }) {
  const busqueda = await llamarMp(`/v1/customers/search?email=${encodeURIComponent(email)}`);
  const existente = busqueda?.results?.[0];
  if (existente) return existente;

  return llamarMp('/v1/customers', { method: 'POST', body: { email } });
}

// Tarjetas guardadas del Customer — para que el Participante las vea (y
// pueda borrarlas) en Perfil. MercadoPago nunca expone el número completo,
// solo los últimos 4 dígitos y la franquicia.
async function listarTarjetasGuardadas(customerId) {
  const tarjetas = await llamarMp(`/v1/customers/${customerId}/cards`);
  return Array.isArray(tarjetas) ? tarjetas : [];
}

async function borrarTarjetaGuardada(customerId, cardId) {
  return llamarMp(`/v1/customers/${customerId}/cards/${cardId}`, { method: 'DELETE' });
}

// Se llama después de autorizar CUALQUIER pago (ver request.controller.js)
// para que la próxima propina ya encuentre la tarjeta guardada. No hace
// falta distinguir "tarjeta nueva" de "tarjeta ya guardada, solo puso el
// CVV" — probado a mano contra el sandbox real (ver DECISIONES_TECNICAS.md
// #45): guardar dos veces la misma tarjeta física (dos tokens distintos,
// mismo número) NO la duplica, MercadoPago la reconoce y deja un solo
// registro. Aun así se llama envuelta en try/catch desde quien la usa: no
// es crítico, nunca debe tirar abajo un pago que ya se autorizó bien.
//
// Ojo: no todas las tarjetas de prueba del sandbox se pueden guardar en un
// Customer — MercadoPago puede responder "payment method not available
// for this card" (código 132) para una tarjeta que sí sirve para pagar
// pero no para esto (confirmado con la Visa 4998 4704 7065 8262; la Visa
// 4509 9535 6623 3704 sí se deja guardar — ver DECISIONES_TECNICAS.md #45).
async function guardarTarjetaEnCustomer(customerId, cardToken) {
  return llamarMp(`/v1/customers/${customerId}/cards`, {
    method: 'POST',
    body: { token: cardToken },
  });
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
  buscarOCrearCustomer,
  listarTarjetasGuardadas,
  borrarTarjetaGuardada,
  guardarTarjetaEnCustomer,
};
