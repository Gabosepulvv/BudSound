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

// Mismo principio que `guardarTokenVerificacion`: se guarda el hash, nunca
// el token en texto plano.
async function guardarTokenReset(id, tokenHash, expiraEn) {
  await pool.query(
    `UPDATE users SET reset_password_token_hash = $2, reset_password_token_expira = $3 WHERE id = $1`,
    [id, tokenHash, expiraEn],
  );
}

// Para mostrar el formulario (GET): solo confirma que el token es válido y
// no vencido, sin consumirlo todavía — consumirlo recién al mandar el
// formulario (`restablecerPassword`) evita que un link pre-cargado por un
// escáner de seguridad de correo (algunos proveedores "visitan" los links
// de un email automáticamente) invalide el token antes de que la persona
// lo use de verdad.
async function buscarPorTokenReset(tokenHash) {
  const { rows } = await pool.query(
    `SELECT id, email, nombre FROM users
     WHERE reset_password_token_hash = $1 AND reset_password_token_expira > now()`,
    [tokenHash],
  );
  return rows[0] || null;
}

// Acá sí se consume el token (atómico, mismo patrón que `verificarPorToken`)
// — esta es la operación que de verdad cambia la contraseña.
async function restablecerPassword(tokenHash, passwordHash) {
  const { rows } = await pool.query(
    `UPDATE users SET
       password_hash = $2,
       reset_password_token_hash = NULL,
       reset_password_token_expira = NULL
     WHERE reset_password_token_hash = $1 AND reset_password_token_expira > now()
     RETURNING id, email, nombre`,
    [tokenHash, passwordHash],
  );
  return rows[0] || null;
}

async function buscarPorId(id) {
  const { rows } = await pool.query(
    `SELECT id, email, role, nombre, apellido, nombre_artistico,
            nombre_artistico_cambiado_at, avatar_data_url, created_at
     FROM users WHERE id = $1`,
    [id],
  );
  return rows[0] || null;
}

// A diferencia de `buscarPorId`, sí incluye `password_hash` — solo para
// confirmar la contraseña antes de una acción destructiva (eliminar
// cuenta). El resto de los controladores no debería usar esta función.
async function buscarConHashPorId(id) {
  const { rows } = await pool.query(
    'SELECT id, password_hash FROM users WHERE id = $1',
    [id],
  );
  return rows[0] || null;
}

// Actualización parcial: solo toca los campos que vienen definidos (no
// undefined) para poder editar nombre/apellido/nombre artístico y la foto
// por separado sin pisar el resto del perfil. `nombreArtistico` actualiza
// también `nombre_artistico_cambiado_at` (las condiciones para permitirlo
// — sin evento activo, máximo 1 vez cada 30 días — ya se validaron en
// auth.controller.js antes de llegar acá).
async function actualizar(id, { nombre, apellido, nombreArtistico, avatarDataUrl }) {
  const { rows } = await pool.query(
    `UPDATE users SET
       nombre = COALESCE($2, nombre),
       apellido = COALESCE($3, apellido),
       nombre_artistico = COALESCE($4, nombre_artistico),
       nombre_artistico_cambiado_at = CASE WHEN $4::text IS NOT NULL THEN now() ELSE nombre_artistico_cambiado_at END,
       avatar_data_url = CASE WHEN $5::boolean THEN $6 ELSE avatar_data_url END
     WHERE id = $1
     RETURNING id, email, role, nombre, apellido, nombre_artistico,
               nombre_artistico_cambiado_at, avatar_data_url, created_at`,
    [
      id,
      nombre ?? null,
      apellido ?? null,
      nombreArtistico ?? null,
      avatarDataUrl !== undefined,
      avatarDataUrl ?? null,
    ],
  );
  return rows[0] || null;
}

// Guarda la conexión OAuth de MercadoPago del DJ (ver
// mercadopago-oauth.service.js). El access_token/refresh_token nunca deben
// salir de acá hacia el cliente — los controladores solo exponen un booleano
// "conectado" (ver DjController/serializarConexion).
async function guardarConexionMercadoPago(
  id,
  { collectorId, accessToken, refreshToken, expiraEn, nickname, email },
) {
  await pool.query(
    `UPDATE users SET
       mp_collector_id = $2,
       mp_access_token = $3,
       mp_refresh_token = $4,
       mp_token_expira = $5,
       mp_nickname = $6,
       mp_email = $7
     WHERE id = $1`,
    [id, collectorId, accessToken, refreshToken, expiraEn, nickname, email],
  );
}

async function buscarConexionMercadoPago(id) {
  const { rows } = await pool.query(
    'SELECT mp_collector_id, mp_access_token, mp_refresh_token, mp_token_expira, mp_nickname, mp_email FROM users WHERE id = $1',
    [id],
  );
  return rows[0] || null;
}

// Las referencias relevantes (eventos si es DJ, solicitudes/transacciones si
// es Participante) tienen `ON DELETE CASCADE` en schema.sql, así que esto
// deja todo consistente solo. Para un DJ esto también borra sus eventos
// pasados (y con ellos las solicitudes/transacciones de esos eventos) — es
// la contrapartida esperada de "eliminar cuenta": no queda nada asociado a
// una cuenta que ya no existe.
async function eliminar(id) {
  await pool.query('DELETE FROM users WHERE id = $1', [id]);
}

async function desconectarMercadoPago(id) {
  await pool.query(
    `UPDATE users SET mp_collector_id = NULL, mp_access_token = NULL, mp_refresh_token = NULL, mp_token_expira = NULL, mp_nickname = NULL, mp_email = NULL
     WHERE id = $1`,
    [id],
  );
}

module.exports = {
  crear,
  buscarPorEmail,
  buscarPorId,
  buscarConHashPorId,
  actualizar,
  eliminar,
  guardarTokenVerificacion,
  verificarPorToken,
  guardarTokenReset,
  buscarPorTokenReset,
  restablecerPassword,
  guardarConexionMercadoPago,
  buscarConexionMercadoPago,
  desconectarMercadoPago,
};
