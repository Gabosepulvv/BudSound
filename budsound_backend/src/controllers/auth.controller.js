const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const userModel = require('../models/user.model');
const googleAuthService = require('../services/google-auth.service');
const emailService = require('../services/email.service');
const { ApiError } = require('../middleware/error.middleware');
const asyncHandler = require('../utils/asyncHandler');

const ROLES_VALIDOS = ['PARTICIPANTE', 'DJ'];

function emailValido(email) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email || '');
}

function firmarToken(user) {
  return jwt.sign({ sub: user.id, role: user.role, email: user.email }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
}

function serializarUsuario(user) {
  return {
    id: user.id,
    email: user.email,
    role: user.role,
    nombre: user.nombre,
    apellido: user.apellido,
    nombreArtistico: user.nombre_artistico,
    avatarDataUrl: user.avatar_data_url,
  };
}

// ~2MB de imagen en base64 pesa ~2.7MB como texto — de sobra para una foto
// de perfil comprimida en el celular antes de subirla.
const AVATAR_MAX_LENGTH = 2_800_000;

const VERIFICACION_HORAS_VALIDEZ = 24;

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

// Genera el token, lo guarda (hasheado) y manda el correo. Si el envío
// falla (credenciales SMTP mal puestas, proveedor caído) no se revienta el
// registro — la cuenta queda creada pero sin verificar, y la persona puede
// pedir que se lo reenvíen (ver `reenviarVerificacion`).
async function generarYEnviarVerificacion(user) {
  const token = crypto.randomBytes(32).toString('hex');
  const expiraEn = new Date(Date.now() + VERIFICACION_HORAS_VALIDEZ * 60 * 60 * 1000);
  await userModel.guardarTokenVerificacion(user.id, hashToken(token), expiraEn);

  const verificationUrl = `${env.publicUrl}/api/auth/verify-email?token=${token}`;
  try {
    await emailService.enviarCorreoVerificacion({
      to: user.email,
      nombre: user.nombre,
      verificationUrl,
    });
  } catch (error) {
    console.error('No se pudo enviar el correo de verificación:', error.message);
  }
}

const registrar = asyncHandler(async (req, res) => {
  const { email, password, role, nombre, apellido, nombreArtistico } = req.body;

  if (!emailValido(email)) throw new ApiError(400, 'El correo electrónico no es válido.');
  if (!password || password.length < 6) {
    throw new ApiError(400, 'La contraseña debe tener al menos 6 caracteres.');
  }
  if (!nombre?.trim() || !apellido?.trim()) {
    throw new ApiError(400, 'Nombre y apellido son obligatorios.');
  }
  if (!ROLES_VALIDOS.includes(role)) {
    throw new ApiError(400, 'El rol debe ser PARTICIPANTE o DJ.');
  }
  if (role === 'DJ' && !nombreArtistico?.trim()) {
    throw new ApiError(400, 'El nombre de DJ es obligatorio.');
  }

  const existente = await userModel.buscarPorEmail(email.trim().toLowerCase());
  if (existente) throw new ApiError(409, 'Ya existe una cuenta con ese correo.');

  // Mientras no haya SMTP configurado, la app funciona igual que antes (sin
  // exigir verificar el correo) — mismo patrón que MercadoPago/Google: una
  // capa de seguridad extra que se activa sola cuando hay credenciales,
  // nunca bloquea el desarrollo local por no tenerlas puestas.
  const requiereVerificacion = emailService.credencialesListas();

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await userModel.crear({
    email: email.trim().toLowerCase(),
    passwordHash,
    role,
    nombre: nombre.trim(),
    apellido: apellido.trim(),
    nombreArtistico: role === 'DJ' ? nombreArtistico.trim() : null,
    emailVerificado: !requiereVerificacion,
  });

  if (requiereVerificacion) {
    await generarYEnviarVerificacion(user);
    return res.status(201).json({
      requiereVerificacion: true,
      email: user.email,
      mensaje: 'Te enviamos un correo para confirmar tu cuenta. Revisa tu bandeja de entrada.',
    });
  }

  res.status(201).json({ token: firmarToken(user), user: serializarUsuario(user) });
});

const iniciarSesion = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!emailValido(email) || !password) {
    throw new ApiError(400, 'Completa correo y contraseña.');
  }

  const user = await userModel.buscarPorEmail(email.trim().toLowerCase());
  if (!user) throw new ApiError(401, 'Credenciales inválidas.');
  if (!user.password_hash) {
    throw new ApiError(401, 'Esta cuenta se creó con Google. Inicia sesión con Google.');
  }

  const coincide = await bcrypt.compare(password, user.password_hash);
  if (!coincide) throw new ApiError(401, 'Credenciales inválidas.');
  if (!user.email_verificado) {
    throw new ApiError(
      403,
      'Verifica tu correo antes de iniciar sesión. Revisa tu bandeja de entrada o pide que te reenviemos el link.',
    );
  }

  res.json({ token: firmarToken(user), user: serializarUsuario(user) });
});

// Público (no requiere sesión): quien toca el botón del correo llega acá
// directo, sin pasar por la app. Siempre responde una página HTML, nunca
// JSON, porque quien abre este link es un navegador, no el cliente HTTP de
// la app.
const verificarCorreo = asyncHandler(async (req, res) => {
  const { token } = req.query;

  const paginaHtml = (titulo, mensaje, ok) => `<!DOCTYPE html>
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

  if (typeof token !== 'string' || !token) {
    return res.status(400).send(paginaHtml('Link inválido', 'Falta el token de verificación.', false));
  }

  const usuario = await userModel.verificarPorToken(hashToken(token));
  if (!usuario) {
    return res.status(400).send(
      paginaHtml(
        'El link ya no es válido',
        'Puede que ya hayas confirmado tu correo, o que el link haya vencido (dura 24 horas). Abre la app y pide que te reenviemos uno nuevo.',
        false,
      ),
    );
  }

  res.send(
    paginaHtml('¡Correo confirmado!', 'Ya puedes volver a la app e iniciar sesión con tu cuenta.', true),
  );
});

// Pide un nuevo link de verificación. Responde el mismo mensaje exista o no
// la cuenta (para no dejarle a cualquiera averiguar qué correos están
// registrados en BudSound probando acá).
const reenviarVerificacion = asyncHandler(async (req, res) => {
  const { email } = req.body;
  const mensaje = 'Si el correo corresponde a una cuenta pendiente de verificar, te enviamos un nuevo link.';

  if (!emailValido(email)) return res.json({ mensaje });
  if (!emailService.credencialesListas()) return res.json({ mensaje });

  const user = await userModel.buscarPorEmail(email.trim().toLowerCase());
  if (user && user.password_hash && !user.email_verificado) {
    await generarYEnviarVerificacion(user);
  }

  res.json({ mensaje });
});

// Un solo endpoint para los dos pasos del login con Google:
//   1. El Participante/DJ toca "Iniciar sesión con Google", el celular
//      consigue un idToken y lo manda sin `role`. Si el email ya existe,
//      se loguea directo. Si no existe, se devuelve `nuevo: true` con el
//      perfil que confirmó Google (nombre, apellido, email) — todavía no
//      se crea nada, porque BudSound necesita saber el rol
//      (Participante/DJ) y Google no lo sabe.
//   2. El frontend muestra un selector de rol y reenvía el MISMO idToken
//      más `role` (y `nombreArtistico` si es DJ). Recién ahí se crea la
//      cuenta — password_hash queda NULL (ver schema.sql).
const google = asyncHandler(async (req, res) => {
  if (!googleAuthService.credencialesListas()) {
    throw new ApiError(503, 'El inicio de sesión con Google no está configurado en este servidor.');
  }

  const { idToken, role, nombreArtistico } = req.body;
  if (!idToken) throw new ApiError(400, 'Falta el token de Google.');

  let perfil;
  try {
    perfil = await googleAuthService.verificarIdToken(idToken);
  } catch (error) {
    throw new ApiError(401, 'No se pudo verificar la cuenta de Google.');
  }

  const existente = await userModel.buscarPorEmail(perfil.email);
  if (existente) {
    return res.json({ token: firmarToken(existente), user: serializarUsuario(existente) });
  }

  if (!role) {
    return res.json({
      nuevo: true,
      perfil: {
        email: perfil.email,
        nombre: perfil.nombre,
        apellido: perfil.apellido,
        avatarDataUrl: perfil.avatarUrl,
      },
    });
  }

  if (!ROLES_VALIDOS.includes(role)) {
    throw new ApiError(400, 'El rol debe ser PARTICIPANTE o DJ.');
  }
  if (role === 'DJ' && !nombreArtistico?.trim()) {
    throw new ApiError(400, 'El nombre de DJ es obligatorio.');
  }

  const user = await userModel.crear({
    email: perfil.email,
    passwordHash: null,
    role,
    nombre: perfil.nombre || 'Participante',
    apellido: perfil.apellido || 'BudSound',
    nombreArtistico: role === 'DJ' ? nombreArtistico.trim() : null,
    avatarDataUrl: perfil.avatarUrl,
    // Google ya verificó el email (se chequeó payload.email_verified en
    // google-auth.service.js) — no tiene sentido pedirle que lo reconfirme.
    emailVerificado: true,
  });

  res.status(201).json({ token: firmarToken(user), user: serializarUsuario(user) });
});

const perfil = asyncHandler(async (req, res) => {
  const user = await userModel.buscarPorId(req.user.sub);
  if (!user) throw new ApiError(404, 'Usuario no encontrado.');
  res.json({ user: serializarUsuario(user) });
});

const actualizarPerfil = asyncHandler(async (req, res) => {
  const { nombre, apellido, avatarDataUrl } = req.body;

  if (nombre !== undefined && !nombre?.trim()) {
    throw new ApiError(400, 'El nombre no puede quedar vacío.');
  }
  if (apellido !== undefined && !apellido?.trim()) {
    throw new ApiError(400, 'El apellido no puede quedar vacío.');
  }
  if (avatarDataUrl !== undefined && avatarDataUrl !== null) {
    if (!/^data:image\/(png|jpe?g|webp);base64,/.test(avatarDataUrl)) {
      throw new ApiError(400, 'La foto de perfil debe ser una imagen PNG, JPEG o WEBP.');
    }
    if (avatarDataUrl.length > AVATAR_MAX_LENGTH) {
      throw new ApiError(400, 'La foto de perfil es muy pesada. Usa una imagen más liviana.');
    }
  }

  const actualizado = await userModel.actualizar(req.user.sub, {
    nombre: nombre?.trim(),
    apellido: apellido?.trim(),
    avatarDataUrl,
  });
  if (!actualizado) throw new ApiError(404, 'Usuario no encontrado.');

  res.json({ user: serializarUsuario(actualizado) });
});

module.exports = {
  registrar,
  iniciarSesion,
  google,
  perfil,
  actualizarPerfil,
  verificarCorreo,
  reenviarVerificacion,
};
