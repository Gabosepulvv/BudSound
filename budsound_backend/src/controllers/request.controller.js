const jwt = require('jsonwebtoken');
const requestModel = require('../models/request.model');
const eventModel = require('../models/event.model');
const transactionModel = require('../models/transaction.model');
const mercadopagoService = require('../services/mercadopago.service');
const mercadopagoOauthService = require('../services/mercadopago-oauth.service');
const env = require('../config/env');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

const MONTO_MIN = 500;
const MONTO_MAX = 20000;
const CHECKOUT_TOKEN_MINUTOS_VALIDEZ = 15;

// Token de alcance acotado para el WebView de pago (ver
// `checkout.controller.js` y `auth.middleware.js` ->
// `requireAuthOrCheckoutScope`): antes esa página recibía el JWT de sesión
// completo (7 días, acceso total a la cuenta) dentro de una página que
// también carga JS de un tercero (SDK de MercadoPago). Este token solo
// sirve para crear la solicitud de ESTE evento, vence en 15 minutos, y
// cualquier otra ruta de la API lo rechaza de entrada (ver `requireAuth`).
const emitirTokenCheckout = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorId(req.params.eventId);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.status !== 'ACTIVO') throw new ApiError(409, 'Este evento ya fue cerrado.');

  const checkoutToken = jwt.sign(
    { sub: req.user.sub, role: 'PARTICIPANTE', scope: 'checkout', eventId: event.id },
    env.jwtSecret,
    { expiresIn: `${CHECKOUT_TOKEN_MINUTOS_VALIDEZ}m` },
  );
  res.json({ checkoutToken });
});

const crear = asyncHandler(async (req, res) => {
  const {
    itunesTrackId,
    titulo,
    artista,
    artworkUrl,
    montoClp,
    terminosAceptados,
    cardToken,
    paymentMethodId,
    installments,
  } = req.body;
  const event = await eventModel.buscarPorId(req.params.eventId);

  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.status !== 'ACTIVO') throw new ApiError(409, 'Este evento ya fue cerrado.');
  if (!itunesTrackId || !titulo?.trim() || !artista?.trim()) {
    throw new ApiError(400, 'Faltan datos de la canción.');
  }

  // La propina es obligatoria para pedir una canción (decisión post-MVP,
  // ver DECISIONES_TECNICAS.md) — múltiplo de 50 para que se pueda pagar
  // en efectivo sin vueltas raras. Mismas reglas que el CHECK de
  // song_requests en schema.sql: esto no es solo para dar un mensaje de
  // error más claro, es la última barrera si alguien se salta la app y
  // pega directo contra la API.
  const monto = Number(montoClp) || 0;
  if (monto < MONTO_MIN || monto > MONTO_MAX || monto % 50 !== 0) {
    throw new ApiError(
      400,
      `El monto debe ser entre $${MONTO_MIN} y $${MONTO_MAX} CLP, en múltiplos de $50.`,
    );
  }
  // El participante debe aceptar explícitamente que no hay devolución una
  // vez que el DJ acepte (ver CLAUDE.md, riesgo "El participante pide la
  // devolución del dinero").
  if (!terminosAceptados) {
    throw new ApiError(400, 'Debes aceptar los Términos y Condiciones para enviar una propina.');
  }
  const pagoReal = mercadopagoService.credencialesListas();
  if (pagoReal && !cardToken) {
    throw new ApiError(400, 'Falta el método de pago para la propina.');
  }

  const request = await requestModel.crear({
    eventId: event.id,
    participanteId: req.user.sub,
    itunesTrackId,
    titulo: titulo.trim(),
    artista: artista.trim(),
    artworkUrl,
    montoClp: monto,
    terminosAceptados: monto > 0 ? true : Boolean(terminosAceptados),
  });

  let transaction = null;
  if (pagoReal) {
    // Autoriza (retiene, no cobra) el pago antes de confirmar la solicitud
    // — ver CLAUDE.md, riesgo "Autorización de pago vs. captura". Si
    // MercadoPago rechaza la tarjeta, la solicitud no llega a existir para
    // el DJ: se borra y se avisa al Participante por qué falló.
    const comisionClp = Math.round(monto * env.commissionRate);
    const montoNetoClp = monto - comisionClp;
    // Si el DJ del evento conectó su propia cuenta de MercadoPago (OAuth
    // marketplace), la propina se autoriza directo ahí, con la comisión de
    // BudSound retenida vía `application_fee` — ver CLAUDE.md, "¿A quién le
    // llega la plata primero?" (Opción A). Si no, se cobra en la cuenta
    // central de BudSound, como siempre.
    const djAccessToken = await mercadopagoOauthService.obtenerAccessTokenVigente(event.dj_id);
    try {
      const pago = await mercadopagoService.autorizarPago({
        requestId: request.id,
        montoClp: monto,
        descripcion: `Propina para ${event.nombre}: ${request.titulo}`,
        token: cardToken,
        paymentMethodId,
        installments,
        payerEmail: req.user.email,
        djAccessToken,
        applicationFee: comisionClp,
      });
      transaction = await transactionModel.crear({
        requestId: request.id,
        montoBrutoClp: monto,
        comisionClp,
        montoNetoClp,
        mpPaymentId: String(pago.id),
        status: 'AUTORIZADA',
      });
    } catch (error) {
      await requestModel.eliminar(request.id);
      throw new ApiError(402, `El pago no se pudo autorizar: ${error.message}`);
    }
  }

  req.io.to(`event:${event.id}`).emit('request:created', { request });

  res.status(201).json({ request, transaction });
});

const listarPorEvento = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorId(req.params.eventId);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const requests = await requestModel.listarPorEvento(event.id, { status: req.query.status });
  res.json({ requests });
});

const misSolicitudesEnEvento = asyncHandler(async (req, res) => {
  const event = await eventModel.buscarPorId(req.params.eventId);
  if (!event) throw new ApiError(404, 'Evento no encontrado.');

  const requests = await requestModel.listarPorEventoYParticipante(event.id, req.user.sub);
  res.json({ requests });
});

async function resolverSolicitud(req, res, nuevoStatus) {
  const request = await requestModel.buscarPorId(req.params.id);
  if (!request) throw new ApiError(404, 'Solicitud no encontrada.');

  const event = await eventModel.buscarPorId(request.event_id);
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const resuelta = await requestModel.resolver(request.id, nuevoStatus);
  if (!resuelta) throw new ApiError(409, 'La solicitud ya fue resuelta.');

  let transaction = null;

  if (mercadopagoService.credencialesListas()) {
    // La propina ya se autorizó al crear la solicitud (ver `crear` arriba)
    // — acá solo se captura (cobra de verdad) o se libera, nunca se crea.
    // Si se autorizó en la cuenta del DJ, capturar/cancelar también debe
    // hacerse con SU token (MercadoPago no deja operar un pago desde una
    // cuenta distinta a la que lo autorizó).
    transaction = await transactionModel.buscarPorRequestId(resuelta.id);
    if (transaction && transaction.status === 'AUTORIZADA') {
      const djAccessToken = await mercadopagoOauthService.obtenerAccessTokenVigente(event.dj_id);
      if (nuevoStatus === 'ACEPTADA') {
        await mercadopagoService.capturarPago(transaction.mp_payment_id, { djAccessToken });
        transaction = await transactionModel.actualizarStatus(transaction.id, 'APROBADA');
      } else {
        await mercadopagoService.cancelarPago(transaction.mp_payment_id, { djAccessToken });
        transaction = await transactionModel.actualizarStatus(transaction.id, 'RECHAZADA');
      }
    }
  } else if (nuevoStatus === 'ACEPTADA' && resuelta.monto_clp > 0) {
    // Sin credenciales reales (ej. otro integrante del equipo sin su propio
    // .env de sandbox): flujo simulado antiguo para poder demostrar el MVP.
    const comisionClp = Math.round(resuelta.monto_clp * env.commissionRate);
    const montoNetoClp = resuelta.monto_clp - comisionClp;

    const pago = await mercadopagoService.crearPreferenciaDePago({
      requestId: resuelta.id,
      montoClp: resuelta.monto_clp,
      descripcion: `Propina para ${event.nombre}: ${resuelta.titulo}`,
    });

    transaction = await transactionModel.crear({
      requestId: resuelta.id,
      montoBrutoClp: resuelta.monto_clp,
      comisionClp,
      montoNetoClp,
      mpPaymentId: pago.preferenceId,
    });
  }

  req.io.to(`event:${event.id}`).emit('request:resolved', { request: resuelta, transaction });
  res.json({ request: resuelta, pago: transaction });
}

const aceptar = asyncHandler((req, res) => resolverSolicitud(req, res, 'ACEPTADA'));
const rechazar = asyncHandler((req, res) => resolverSolicitud(req, res, 'RECHAZADA'));

// Evidencia con timestamp de que la canción sonó — ver CLAUDE.md, riesgo
// "Contracargo": es lo único que se puede aportar como prueba interna si
// MercadoPago abre una disputa por un pago ya capturado.
const marcarReproducida = asyncHandler(async (req, res) => {
  const request = await requestModel.buscarPorId(req.params.id);
  if (!request) throw new ApiError(404, 'Solicitud no encontrada.');

  const event = await eventModel.buscarPorId(request.event_id);
  if (event.dj_id !== req.user.sub) throw new ApiError(403, 'No eres el dueño de este evento.');

  const actualizada = await requestModel.marcarReproducida(request.id);
  if (!actualizada) {
    throw new ApiError(409, 'Solo se puede marcar como reproducida una solicitud aceptada, una vez.');
  }

  req.io.to(`event:${event.id}`).emit('request:played', { request: actualizada });
  res.json({ request: actualizada });
});

module.exports = {
  crear,
  listarPorEvento,
  misSolicitudesEnEvento,
  aceptar,
  rechazar,
  marcarReproducida,
  emitirTokenCheckout,
};
