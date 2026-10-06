const { OAuth2Client } = require('google-auth-library');
const env = require('../config/env');

const client = new OAuth2Client(env.googleClientId);

const credencialesListas = () => Boolean(env.googleClientId);

// Verifica el idToken contra las claves públicas de Google (JWKS) — nunca
// se confía en el email que mande el celular, solo en lo que Google firmó
// y cuya audiencia coincide con nuestro propio Client ID.
async function verificarIdToken(idToken) {
  const ticket = await client.verifyIdToken({
    idToken,
    audience: env.googleClientId,
  });
  const payload = ticket.getPayload();
  if (!payload || !payload.email || !payload.email_verified) {
    throw new Error('No se pudo verificar la cuenta de Google.');
  }
  return {
    email: payload.email.toLowerCase(),
    nombre: payload.given_name || '',
    apellido: payload.family_name || '',
    avatarUrl: payload.picture || null,
  };
}

module.exports = { verificarIdToken, credencialesListas };
