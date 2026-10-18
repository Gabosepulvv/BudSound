const env = require('../config/env');
const userModel = require('../models/user.model');

const MP_API = 'https://api.mercadopago.com';
const MP_AUTH_URL = 'https://auth.mercadopago.com/authorization';

const credencialesListas = () =>
  Boolean(env.mercadopago.clientId && env.mercadopago.clientSecret);

function redirectUri() {
  return `${env.publicUrl}/api/dj/mercadopago/callback`;
}

// URL a la que se manda al DJ para que inicie sesión en SU cuenta de
// MercadoPago y autorice a BudSound — nunca dentro de un WebView propio
// (eso sería pedirle su contraseña de MercadoPago a una página que
// controlamos nosotros): se abre en el navegador del sistema, ver
// `mp_connect_service.dart` y CLAUDE.md, revisión de seguridad.
function urlAutorizacion(state) {
  const params = new URLSearchParams({
    client_id: env.mercadopago.clientId,
    response_type: 'code',
    platform_id: 'mp',
    redirect_uri: redirectUri(),
    state,
  });
  return `${MP_AUTH_URL}?${params.toString()}`;
}

async function intercambiarCodigo(code) {
  const response = await fetch(`${MP_API}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: env.mercadopago.clientId,
      client_secret: env.mercadopago.clientSecret,
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri(),
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data?.message || 'MercadoPago rechazó la conexión de la cuenta.');
    error.mpData = data;
    throw error;
  }
  return data; // { access_token, refresh_token, user_id, public_key, expires_in, ... }
}

async function refrescarToken(refreshToken) {
  const response = await fetch(`${MP_API}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: env.mercadopago.clientId,
      client_secret: env.mercadopago.clientSecret,
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(data?.message || 'No se pudo renovar la conexión con MercadoPago.');
    error.mpData = data;
    throw error;
  }
  return data;
}

// Nickname/correo de la cuenta recién conectada — se muestran en Perfil
// para que el DJ pueda confirmar que quedó la cuenta correcta (un
// `collector_id` numérico solo no le dice nada a simple vista).
async function obtenerIdentidad(accessToken) {
  const response = await fetch(`${MP_API}/users/me`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) return { nickname: null, email: null };
  return { nickname: data.nickname ?? null, email: data.email ?? null };
}

const MARGEN_REFRESCO_MS = 5 * 60 * 1000;

// Access token vigente del DJ para usar en un pago (o null si no conectó su
// cuenta). Si está por vencer (o ya venció), lo renueva solo con el
// refresh_token antes de devolverlo — quien llama no necesita saber nada de
// esto, solo recibe un token listo para usar o null.
async function obtenerAccessTokenVigente(djId) {
  const conexion = await userModel.buscarConexionMercadoPago(djId);
  if (!conexion?.mp_access_token) return null;

  const vigente =
    conexion.mp_token_expira && new Date(conexion.mp_token_expira).getTime() - Date.now() > MARGEN_REFRESCO_MS;
  if (vigente) return conexion.mp_access_token;

  try {
    const renovado = await refrescarToken(conexion.mp_refresh_token);
    await userModel.guardarConexionMercadoPago(djId, {
      collectorId: renovado.user_id,
      accessToken: renovado.access_token,
      refreshToken: renovado.refresh_token,
      expiraEn: new Date(Date.now() + renovado.expires_in * 1000),
      // El refresco no cambia de cuenta — se conservan los que ya había.
      nickname: conexion.mp_nickname,
      email: conexion.mp_email,
    });
    return renovado.access_token;
  } catch (error) {
    console.error('No se pudo renovar el token de MercadoPago del DJ:', error.message);
    // El token viejo puede seguir sirviendo aunque la renovación falle
    // (ej. MercadoPago no respondió a tiempo) — se intenta igual en vez de
    // cortar el cobro de una.
    return conexion.mp_access_token;
  }
}

module.exports = {
  credencialesListas,
  urlAutorizacion,
  intercambiarCodigo,
  refrescarToken,
  obtenerAccessTokenVigente,
  obtenerIdentidad,
};
