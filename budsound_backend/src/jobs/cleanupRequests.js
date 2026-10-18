const requestModel = require('../models/request.model');
const transactionModel = require('../models/transaction.model');
const mercadopagoService = require('../services/mercadopago.service');
const mercadopagoOauthService = require('../services/mercadopago-oauth.service');
const env = require('../config/env');

/// Revisa solicitudes PENDIENTE colgadas y las cancela automáticamente
/// (ver CLAUDE.md, riesgo "Autorización de pago vs. captura"). Notifica a
/// cada sala de evento por Socket.io para que las UI conectadas se
/// actualicen sin esperar un refresh manual.
async function limpiarSolicitudesColgadas(io) {
  const canceladas = await requestModel.cancelarSolicitudesColgadas(env.requestTimeoutMinutes);

  if (canceladas.length === 0) return 0;

  // Cada solicitud colgada con propina tiene una autorización de
  // MercadoPago retenida desde que se creó (captura diferida) — si no se
  // libera acá, el dinero del Participante queda retenido hasta que la
  // autorización expire sola a los 7 días.
  if (mercadopagoService.credencialesListas()) {
    for (const { id: requestId, dj_id: djId } of canceladas) {
      const transaction = await transactionModel.buscarPorRequestId(requestId);
      if (transaction?.status !== 'AUTORIZADA') continue;
      try {
        const djAccessToken = await mercadopagoOauthService.obtenerAccessTokenVigente(djId);
        await mercadopagoService.cancelarPago(transaction.mp_payment_id, { djAccessToken });
        await transactionModel.actualizarStatus(transaction.id, 'RECHAZADA');
      } catch (error) {
        console.error(
          `No se pudo liberar la autorización de MercadoPago de la solicitud ${requestId}:`,
          error.message,
        );
      }
    }
  }

  const porEvento = new Map();
  for (const { id, event_id: eventId } of canceladas) {
    if (!porEvento.has(eventId)) porEvento.set(eventId, []);
    porEvento.get(eventId).push(id);
  }

  for (const [eventId, ids] of porEvento) {
    io.to(`event:${eventId}`).emit('request:resolved', { requestIds: ids });
  }

  console.log(`Limpieza automática: ${canceladas.length} solicitud(es) cancelada(s) por estar colgada(s).`);
  return canceladas.length;
}

/// Arranca el barrido periódico. Corre una vez al iniciar y luego cada
/// [env.cleanupIntervalMinutes] minutos — nunca depende de que alguien lo
/// dispare a mano.
function iniciarLimpiezaPeriodica(io) {
  const intervaloMs = env.cleanupIntervalMinutes * 60 * 1000;

  limpiarSolicitudesColgadas(io).catch((error) => {
    console.error('Error en la limpieza inicial de solicitudes colgadas:', error.message);
  });

  return setInterval(() => {
    limpiarSolicitudesColgadas(io).catch((error) => {
      console.error('Error en la limpieza periódica de solicitudes colgadas:', error.message);
    });
  }, intervaloMs);
}

module.exports = { limpiarSolicitudesColgadas, iniciarLimpiezaPeriodica };
