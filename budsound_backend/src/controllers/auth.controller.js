const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const userModel = require('../models/user.model');
const googleAuthService = require('../services/google-auth.service');
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

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await userModel.crear({
    email: email.trim().toLowerCase(),
    passwordHash,
    role,
    nombre: nombre.trim(),
    apellido: apellido.trim(),
    nombreArtistico: role === 'DJ' ? nombreArtistico.trim() : null,
  });

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

  res.json({ token: firmarToken(user), user: serializarUsuario(user) });
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

module.exports = { registrar, iniciarSesion, google, perfil, actualizarPerfil };
