const { pool } = require('../config/db');

async function crear({
  email,
  passwordHash,
  role,
  nombre,
  apellido,
  nombreArtistico,
  avatarDataUrl,
  emailVerificado,
}) {
  const { rows } = await pool.query(
    `INSERT INTO users (email, password_hash, role, nombre, apellido, nombre_artistico, avatar_data_url, email_verificado)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, email, role, nombre, apellido, nombre_artistico, avatar_data_url, email_verificado, created_at`,
    [
      email,
      passwordHash || null,
      role,
      nombre,
      apellido,
      nombreArtistico || null,
      avatarDataUrl || null,
      Boolean(emailVerificado),
    ],
  );
  return rows[0];
}

// Guarda el hash del token de verificación (nunca el token en texto plano —
// mismo principio que un password hash: si la base de datos se filtra, nadie
// puede armar el link de verificación de otra persona con lo que ahí queda).
async function guardarTokenVerificacion(id, tokenHash, expiraEn) {
  await pool.query(
    `UPDATE users SET verificacion_token_hash = $2, verificacion_token_expira = $3 WHERE id = $1`,
    [id, tokenHash, expiraEn],
  );
}

// Verifica y limpia el token en una sola operación atómica: si dos personas
// (o un reintento de red) tocan el link al mismo tiempo, solo una gana la
// fila con el token todavía sin limpiar.
async function verificarPorToken(tokenHash) {
  const { rows } = await pool.query(
    `UPDATE users SET
       email_verificado = true,
       verificacion_token_hash = NULL,
       verificacion_token_expira = NULL
     WHERE verificacion_token_hash = $1 AND verificacion_token_expira > now()
     RETURNING id, email, nombre`,
    [tokenHash],
  );
  return rows[0] || null;
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

module.exports = {
  crear,
  buscarPorEmail,
  buscarPorId,
  actualizar,
  guardarTokenVerificacion,
  verificarPorToken,
};
