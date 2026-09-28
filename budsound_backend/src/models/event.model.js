const { pool } = require('../config/db');

async function crear({ djId, code, nombre }) {
  const { rows } = await pool.query(
    `INSERT INTO events (dj_id, code, nombre)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [djId, code, nombre],
  );
  return rows[0];
}

async function buscarPorCodigo(code) {
  const { rows } = await pool.query('SELECT * FROM events WHERE code = $1', [code]);
  return rows[0] || null;
}

async function buscarPorId(id) {
  const { rows } = await pool.query('SELECT * FROM events WHERE id = $1', [id]);
  return rows[0] || null;
}

async function listarPorDj(djId) {
  const { rows } = await pool.query(
    'SELECT * FROM events WHERE dj_id = $1 ORDER BY created_at DESC',
    [djId],
  );
  return rows;
}

async function cerrar(id) {
  const { rows } = await pool.query(
    `UPDATE events SET status = 'CERRADO', closed_at = now()
     WHERE id = $1 AND status = 'ACTIVO'
     RETURNING *`,
    [id],
  );
  return rows[0] || null;
}

async function resumenRecaudacion(eventId) {
  const { rows } = await pool.query(
    `SELECT
       COUNT(*) FILTER (WHERE sr.status = 'ACEPTADA') AS solicitudes_aceptadas,
       COUNT(*) AS solicitudes_totales,
       COALESCE(SUM(t.monto_bruto_clp) FILTER (WHERE t.status = 'APROBADA'), 0) AS recaudacion_bruta_clp,
       COALESCE(SUM(t.comision_clp) FILTER (WHERE t.status = 'APROBADA'), 0) AS comision_total_clp,
       COALESCE(SUM(t.monto_neto_clp) FILTER (WHERE t.status = 'APROBADA'), 0) AS recaudacion_neta_clp
     FROM song_requests sr
     LEFT JOIN transactions t ON t.request_id = sr.id
     WHERE sr.event_id = $1`,
    [eventId],
  );
  return rows[0];
}

module.exports = { crear, buscarPorCodigo, buscarPorId, listarPorDj, cerrar, resumenRecaudacion };
