const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const env = require('../config/env');
const userModel = require('../models/user.model');
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

  const coincide = await bcrypt.compare(password, user.password_hash);
  if (!coincide) throw new ApiError(401, 'Credenciales inválidas.');

  res.json({ token: firmarToken(user), user: serializarUsuario(user) });
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

module.exports = { registrar, iniciarSesion, perfil, actualizarPerfil };
