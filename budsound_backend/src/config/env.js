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
    // OAuth "Mercado Pago como marketplace": permite que cada DJ conecte su
    // propia cuenta (ver mercadopago-oauth.service.js). Son credenciales
    // distintas del Access Token/Public Key de arriba — están en la pestaña
    // "OAuth" de las credenciales de la aplicación en el panel de
    // MercadoPago. Mientras falten, el botón "Conectar MercadoPago" del DJ
    // queda deshabilitado y las propinas se siguen cobrando en la cuenta
    // central de BudSound, como hasta ahora.
    clientId: process.env.MERCADOPAGO_CLIENT_ID || '',
    clientSecret: process.env.MERCADOPAGO_CLIENT_SECRET || '',
  },
  // Client ID "Web" del proyecto de Google Cloud Console — el mismo que usa
  // la app Flutter como `serverClientId` para que el idToken que genera
  // venga dirigido a esta audiencia (ver google-auth.service.js).
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  // Correo de verificación al registrarse (ver email.service.js), vía la
  // API HTTP de Brevo — no SMTP directo: Railway bloquea el tráfico
  // saliente por los puertos SMTP (25/465/587) por completo (confirmado
  // 2026-10-18, ver DECISIONES_TECNICAS.md), así que Gmail por SMTP nunca
  // iba a funcionar ahí sin importar las credenciales. Mientras no esté
  // configurado, el registro no exige verificar el correo (mismo patrón
  // que MercadoPago/Google: la app funciona igual sin credenciales, solo
  // que sin esa capa extra).
  // .trim() porque un espacio/tab accidental al pegar el valor en el panel
  // de Railway (pasó con SMTP_HOST antes de este cambio) puede romper el
  // valor de forma nada obvia.
  email: {
    apiKey: (process.env.BREVO_API_KEY || '').trim(),
    senderEmail: (process.env.EMAIL_SENDER || '').trim(),
    senderName: (process.env.EMAIL_SENDER_NAME || 'BudSound').trim(),
  },
  // URL pública donde este backend responde (para armar el link del correo
  // de verificación) — en Railway, el dominio que genera "Networking ->
  // Generate Domain" (ver RAILWAY_DEPLOY.md).
  publicUrl: process.env.PUBLIC_URL || `http://localhost:${Number(process.env.PORT) || 3000}`,
  commissionRate: Number(process.env.BUDSOUND_COMMISSION_RATE) || 0.08,
  // Ver CLAUDE.md, riesgo "Autorización de pago vs. captura": una solicitud
  // pendiente no puede quedar colgada para siempre. 7 minutos porque es un
  // evento en vivo — el Participante está ahí mismo esperando una
  // respuesta, no tiene sentido hacerlo esperar horas como con una compra
  // online común.
  requestTimeoutMinutes: Number(process.env.REQUEST_TIMEOUT_MINUTES) || 7,
  // Corre seguido (no cada 15 min como antes) porque el plazo mismo ahora
  // es de minutos, no de horas — si el barrido corriera cada 15 min, una
  // solicitud podría quedar "vencida" sin cancelarse hasta 15 minutos
  // después de cumplirse el plazo.
  cleanupIntervalMinutes: Number(process.env.CLEANUP_INTERVAL_MINUTES) || 1,
};
