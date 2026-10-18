const jwt = require('jsonwebtoken');
const env = require('../config/env');
const userModel = require('../models/user.model');
const mpOauthService = require('../services/mercadopago-oauth.service');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

const STATE_MINUTOS_VALIDEZ = 10;

// El "state" de OAuth identifica qué DJ inició la conexión cuando
// MercadoPago vuelve a llamar al callback (ese request no trae el JWT de
// sesión del DJ — es un redirect del navegador, no una llamada de la app).
// Firmado con el mismo secreto que el resto de los JWT, con `purpose` para
// que no se pueda reusar un token de sesión normal como si fuera un state.
function firmarState(djId) {
  return jwt.sign({ sub: djId, purpose: 'mp-connect' }, env.jwtSecret, {
    expiresIn: `${STATE_MINUTOS_VALIDEZ}m`,
  });
}

function verificarState(state) {
  const payload = jwt.verify(state, env.jwtSecret);
  if (payload.purpose !== 'mp-connect') throw new Error('state inválido');
  return payload.sub;
}

function paginaHtml(titulo, mensaje, ok) {
  return `<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${titulo}</title></head>
<body style="margin:0;background:#070B14;font-family:-apple-system,system-ui,sans-serif;
  display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;box-sizing:border-box;">
  <div style="max-width:380px;text-align:center;background:#0D1626;border:1px solid #1E2C44;
    border-radius:18px;padding:36px 28px;">
    <div style="font-size:40px;line-height:1;margin-bottom:12px;">${ok ? '✅' : '⚠️'}</div>
    <h1 style="color:#FFFFFF;font-size:18px;margin:0 0 8px;">${titulo}</h1>
    <p style="color:#93A2BE;font-size:14px;line-height:1.5;margin:0;">${mensaje}</p>
  </div>
</body></html>`;
}

// Devuelve la URL a la que la app debe mandar al DJ (navegador del
// sistema, nunca un WebView propio — ver mercadopago-oauth.service.js) para
// que inicie sesión en SU cuenta de MercadoPago y autorice a BudSound.
const iniciarConexion = asyncHandler(async (req, res) => {
  if (!mpOauthService.credencialesListas()) {
    throw new ApiError(503, 'La conexión con MercadoPago todavía no está configurada en este servidor.');
  }
  const authUrl = mpOauthService.urlAutorizacion(firmarState(req.user.sub));
  res.json({ authUrl });
});

// Público (MercadoPago redirige acá directo, sin JWT de sesión). Siempre
// responde HTML, nunca JSON — quien llega es un navegador, no la app.
const callback = asyncHandler(async (req, res) => {
  const { code, state, error: errorMp } = req.query;

  if (errorMp) {
    return res.status(400).send(
      paginaHtml('Conexión cancelada', 'No autorizaste la conexión con MercadoPago. Vuelve a la app e inténtalo de nuevo si fue un error.', false),
    );
  }
  if (typeof code !== 'string' || typeof state !== 'string') {
    return res.status(400).send(paginaHtml('Link inválido', 'Faltan datos para completar la conexión.', false));
  }

  let djId;
  try {
    djId = verificarState(state);
  } catch (error) {
    return res.status(400).send(
      paginaHtml('Link vencido', 'Este link de conexión ya no es válido (vence a los 10 minutos). Vuelve a la app e inténtalo de nuevo.', false),
    );
  }

  try {
    const token = await mpOauthService.intercambiarCodigo(code);
    const identidad = await mpOauthService.obtenerIdentidad(token.access_token);
    await userModel.guardarConexionMercadoPago(djId, {
      collectorId: token.user_id,
      accessToken: token.access_token,
      refreshToken: token.refresh_token,
      expiraEn: new Date(Date.now() + token.expires_in * 1000),
      nickname: identidad.nickname,
      email: identidad.email,
    });
  } catch (error) {
    console.error('Error conectando MercadoPago del DJ:', error.message);
    return res.status(500).send(
      paginaHtml('No se pudo conectar', 'Hubo un problema confirmando la conexión con MercadoPago. Vuelve a la app e inténtalo de nuevo.', false),
    );
  }

  res.send(
    paginaHtml('¡Cuenta conectada!', 'Tu cuenta de MercadoPago quedó conectada. Ya puedes volver a la app — las propinas de tus eventos van a llegar directo a tu cuenta.', true),
  );
});

const estado = asyncHandler(async (req, res) => {
  const conexion = await userModel.buscarConexionMercadoPago(req.user.sub);
  res.json({
    conectado: Boolean(conexion?.mp_access_token),
    collectorId: conexion?.mp_collector_id ?? null,
    nickname: conexion?.mp_nickname ?? null,
    email: conexion?.mp_email ?? null,
  });
});

const desconectar = asyncHandler(async (req, res) => {
  await userModel.desconectarMercadoPago(req.user.sub);
  res.json({ conectado: false });
});

module.exports = { iniciarConexion, callback, estado, desconectar };
