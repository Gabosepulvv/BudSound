const { pool } = require('../config/db');

async function crear({ email, passwordHash, role, nombre, apellido, nombreArtistico }) {
  const { rows } = await pool.query(
    `INSERT INTO users (email, password_hash, role, nombre, apellido, nombre_artistico)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, email, role, nombre, apellido, nombre_artistico, created_at`,
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
    'SELECT id, email, role, nombre, apellido, nombre_artistico, created_at FROM users WHERE id = $1',
    [id],
  );
  return rows[0] || null;
}

module.exports = { crear, buscarPorEmail, buscarPorId };
