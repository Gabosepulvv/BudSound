const jwt = require('jsonwebtoken');
const env = require('../config/env');

function verificarToken(req) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    const error = new Error('Token de autenticación faltante.');
    error.status = 401;
    throw error;
  }
  try {
    return jwt.verify(token, env.jwtSecret);
  } catch (error) {
    error.status = 401;
    error.message = 'Token inválido o expirado.';
    throw error;
  }
}

function requireAuth(req, res, next) {
  try {
    const payload = verificarToken(req);
    // Un token de alcance acotado (ej. "checkout", ver
    // requireAuthOrCheckoutScope) nunca debe servir para el resto de la
    // API, aunque la firma sea válida — si trae `scope`, no es un login
    // normal y esta ruta no lo acepta.
    if (payload.scope) {
      return res.status(401).json({ error: 'Token inválido para esta operación.' });
    }
    req.user = payload;
    return next();
  } catch (error) {
    return res.status(error.status || 401).json({ error: error.message });
  }
}

// Acepta el JWT normal de sesión (igual que requireAuth) O un token de
// checkout de corta duración emitido solo para pagar y crear UNA solicitud
// puntual (ver request.controller.js `emitirTokenCheckout` y
// `checkout.controller.js`). Se usa únicamente en la ruta de creación de
// solicitudes, a la que llama tanto la app directo (solicitudes sin
// propina) como el WebView de pago (con propina) — ver
// DECISIONES_TECNICAS.md, "token de checkout acotado".
function requireAuthOrCheckoutScope(req, res, next) {
  let payload;
  try {
    payload = verificarToken(req);
  } catch (error) {
    return res.status(error.status || 401).json({ error: error.message });
  }

  if (payload.scope === 'checkout') {
    if (payload.eventId !== req.params.eventId) {
      return res.status(403).json({ error: 'Este token de pago no es para este evento.' });
    }
  } else if (payload.scope) {
    return res.status(401).json({ error: 'Token inválido para esta operación.' });
  }

  req.user = payload;
  return next();
}

function requireRole(...rolesPermitidos) {
  return (req, res, next) => {
    if (!req.user || !rolesPermitidos.includes(req.user.role)) {
      return res.status(403).json({ error: 'No tienes permiso para esta acción.' });
    }
    return next();
  };
}

module.exports = { requireAuth, requireAuthOrCheckoutScope, requireRole };
