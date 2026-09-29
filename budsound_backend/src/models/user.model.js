const { pool } = require('../config/db');

async function crear({ email, passwordHash, role, nombre, apellido, nombreArtistico }) {
  const { rows } = await pool.query(
    `INSERT INTO users (email, password_hash, role, nombre, apellido, nombre_artistico)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, email, role, nombre, apellido, nombre_artistico, avatar_data_url, created_at`,
    [email, passwordHash, role, nombre, apellido, nombreArtistico || null],
  );
  return rows[0];
}

async function buscarPorEmail(email) {
  const { rows } = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return rows[0] || null;
}

async function buscarPorId(id) {
  const { rows } = await pool.query(
    'SELECT id, email, role, nombre, apellido, nombre_artistico, avatar_data_url, created_at FROM users WHERE id = $1',
    [id],
  );
  return rows[0] || null;
}

// Actualización parcial: solo toca los campos que vienen definidos (no
// undefined) para poder editar nombre/apellido y la foto por separado sin
// pisar el resto del perfil.
async function actualizar(id, { nombre, apellido, avatarDataUrl }) {
  const { rows } = await pool.query(
    `UPDATE users SET
       nombre = COALESCE($2, nombre),
       apellido = COALESCE($3, apellido),
       avatar_data_url = CASE WHEN $4::boolean THEN $5 ELSE avatar_data_url END
     WHERE id = $1
     RETURNING id, email, role, nombre, apellido, nombre_artistico, avatar_data_url, created_at`,
    [id, nombre ?? null, apellido ?? null, avatarDataUrl !== undefined, avatarDataUrl ?? null],
  );
  return rows[0] || null;
}

module.exports = { crear, buscarPorEmail, buscarPorId, actualizar };
