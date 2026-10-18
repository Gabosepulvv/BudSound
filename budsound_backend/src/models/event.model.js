const { pool } = require('../config/db');

async function crear({
  djId,
  code,
  nombre,
  horaInicio,
  horaFin,
  fechaInicio,
  fechaFin,
  generos,
  imagenDataUrl,
}) {
  const { rows } = await pool.query(
    `INSERT INTO events (dj_id, code, nombre, hora_inicio, hora_fin, fecha_inicio, fecha_fin, generos, imagen_data_url)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING *`,
    [
      djId,
      code,
      nombre,
      horaInicio,
      horaFin,
      fechaInicio,
      fechaFin,
      generos,
      imagenDataUrl || null,
    ],
  );
  return rows[0];
}

// El nombre artístico y la foto del DJ no viven en `events` — se traen con
// un JOIN acá para que el Participante pueda mostrarlos en su tarjeta de
// "evento actual" (Inicio) sin un segundo viaje al backend. `buscarPorId`
// la usa tanto el DJ (que no necesita estas dos columnas, pero no cuesta
// nada traerlas) como el Participante al abrir el evento.
const SELECT_CON_DJ = `
  SELECT e.*, u.nombre_artistico AS dj_nombre_artistico, u.avatar_data_url AS dj_avatar_data_url
  FROM events e
  JOIN users u ON u.id = e.dj_id
`;

async function buscarPorCodigo(code) {
  const { rows } = await pool.query(`${SELECT_CON_DJ} WHERE e.code = $1`, [code]);
  return rows[0] || null;
}

async function buscarPorId(id) {
  const { rows } = await pool.query(`${SELECT_CON_DJ} WHERE e.id = $1`, [id]);
  return rows[0] || null;
}

async function listarPorDj(djId) {
  const { rows } = await pool.query(
    'SELECT * FROM events WHERE dj_id = $1 ORDER BY created_at DESC',
    [djId],
  );
  return rows;
}

// Un DJ no puede tener más de un evento ACTIVO a la vez (ver
// event.controller.js, `crear`) — esto es lo que decide si ya tiene uno.
async function buscarActivoPorDj(djId) {
  const { rows } = await pool.query(
    "SELECT * FROM events WHERE dj_id = $1 AND status = 'ACTIVO' LIMIT 1",
    [djId],
  );
  return rows[0] || null;
}

// `imagenDataUrl` puede venir `null` a propósito (quitar la imagen) — por
// eso no usa COALESCE como `user.model.js actualizar`: acá siempre se
// reemplaza por el valor que llega, nunca se "mantiene" el anterior
// (la decisión de mandar o no el campo ya la tomó `event.controller.js`).
async function actualizarImagen(id, imagenDataUrl) {
  const { rows } = await pool.query(
    `UPDATE events SET imagen_data_url = $2 WHERE id = $1 RETURNING *`,
    [id, imagenDataUrl || null],
  );
  return rows[0] || null;
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

// Resumen de TODA la carrera del DJ en BudSound (todos sus eventos, no uno
// solo) — para la sección de "Tus estadísticas" de Inicio. Mismo criterio
// que `resumenRecaudacion` (solo transacciones APROBADA cuentan como
// recaudación real).
async function resumenGeneralPorDj(djId) {
  const { rows } = await pool.query(
    `SELECT
       COUNT(DISTINCT e.id) AS eventos_totales,
       COUNT(DISTINCT e.id) FILTER (WHERE e.status = 'CERRADO') AS eventos_cerrados,
       COUNT(sr.id) FILTER (WHERE sr.status = 'ACEPTADA') AS solicitudes_aceptadas,
       COALESCE(SUM(t.monto_neto_clp) FILTER (WHERE t.status = 'APROBADA'), 0) AS recaudacion_neta_clp
     FROM events e
     LEFT JOIN song_requests sr ON sr.event_id = e.id
     LEFT JOIN transactions t ON t.request_id = sr.id
     WHERE e.dj_id = $1`,
    [djId],
  );
  return rows[0];
}

module.exports = {
  crear,
  buscarPorCodigo,
  buscarPorId,
  listarPorDj,
  buscarActivoPorDj,
  actualizarImagen,
  cerrar,
  resumenRecaudacion,
  resumenGeneralPorDj,
};
