require('dotenv').config();

function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined) {
    throw new Error(`Falta la variable de entorno ${name}`);
  }
  return value;
}

module.exports = {
  port: Number(process.env.PORT) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  databaseUrl: required('DATABASE_URL'),
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  mercadopago: {
    accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN || '',
    publicKey: process.env.MERCADOPAGO_PUBLIC_KEY || '',
  },
  // Client ID "Web" del proyecto de Google Cloud Console — el mismo que usa
  // la app Flutter como `serverClientId` para que el idToken que genera
  // venga dirigido a esta audiencia (ver google-auth.service.js).
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  commissionRate: Number(process.env.BUDSOUND_COMMISSION_RATE) || 0.08,
  // Ver CLAUDE.md, riesgo "Autorización de pago vs. captura": una solicitud
  // pendiente no puede quedar colgada para siempre.
  requestTimeoutHours: Number(process.env.REQUEST_TIMEOUT_HOURS) || 6,
  cleanupIntervalMinutes: Number(process.env.CLEANUP_INTERVAL_MINUTES) || 15,
};
