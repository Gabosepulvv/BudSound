const { pool } = require('../config/db');

async function crear({ eventId, participanteId, itunesTrackId, titulo, artista, artworkUrl, montoClp }) {
  const { rows } = await pool.query(
    `INSERT INTO song_requests
       (event_id, participante_id, itunes_track_id, titulo, artista, artwork_url, monto_clp)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [eventId, participanteId, itunesTrackId, titulo, artista, artworkUrl || null, montoClp || 0],
  );
  return rows[0];
}

async function buscarPorId(id) {
  const { rows } = await pool.query('SELECT * FROM song_requests WHERE id = $1', [id]);
  return rows[0] || null;
}

async function listarPorEvento(eventId, { status } = {}) {
  const params = [eventId];
  let query = `
    SELECT sr.*, u.nombre AS participante_nombre, u.apellido AS participante_apellido
    FROM song_requests sr
    JOIN users u ON u.id = sr.participante_id
    WHERE sr.event_id = $1`;

  if (status) {
    params.push(status);
    query += ` AND sr.status = $${params.length}`;
  }

  query += ' ORDER BY sr.created_at ASC';
  const { rows } = await pool.query(query, params);
  return rows;
}

async function listarPorEventoYParticipante(eventId, participanteId) {
  const { rows } = await pool.query(
    `SELECT * FROM song_requests
     WHERE event_id = $1 AND participante_id = $2
     ORDER BY created_at ASC`,
    [eventId, participanteId],
  );
  return rows;
}

async function resolver(id, status) {
  const { rows } = await pool.query(
    `UPDATE song_requests SET status = $2, resolved_at = now()
     WHERE id = $1 AND status = 'PENDIENTE'
     RETURNING *`,
    [id, status],
  );
  return rows[0] || null;
}

module.exports = {
  crear,
  buscarPorId,
  listarPorEvento,
  listarPorEventoYParticipante,
  resolver,
};
