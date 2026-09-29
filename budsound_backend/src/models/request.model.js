const { pool } = require('../config/db');

async function crear({
  eventId,
  participanteId,
  itunesTrackId,
  titulo,
  artista,
  artworkUrl,
  montoClp,
  terminosAceptados,
}) {
  const { rows } = await pool.query(
    `INSERT INTO song_requests
       (event_id, participante_id, itunes_track_id, titulo, artista, artwork_url, monto_clp, terminos_aceptados)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      eventId,
      participanteId,
      itunesTrackId,
      titulo,
      artista,
      artworkUrl || null,
      montoClp || 0,
      Boolean(terminosAceptados),
    ],
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

// Evidencia con timestamp de que la canción sonó de verdad — es lo que se
// usa para disputar un contracargo de MercadoPago (ver CLAUDE.md, riesgo
// "Contracargo").
async function marcarReproducida(id) {
  const { rows } = await pool.query(
    `UPDATE song_requests SET reproducida_at = now()
     WHERE id = $1 AND status = 'ACEPTADA' AND reproducida_at IS NULL
     RETURNING *`,
    [id],
  );
  return rows[0] || null;
}

// Cancela solicitudes que quedaron "colgadas": el evento ya cerró, o pasaron
// más de [timeoutHours] sin que el DJ respondiera. Nunca depende de que
// alguien lo haga a mano (ver CLAUDE.md, riesgo "Autorización de pago vs.
// captura" — la vigencia real de una autorización de MercadoPago es de 7
// días, pero acá se usa un plazo mucho más corto porque no tiene sentido
// dejar a alguien esperando toda la noche una respuesta que nunca llegó).
async function cancelarSolicitudesColgadas(timeoutHours) {
  const { rows } = await pool.query(
    `UPDATE song_requests sr
     SET status = 'CANCELADA', resolved_at = now()
     FROM events e
     WHERE sr.event_id = e.id
       AND sr.status = 'PENDIENTE'
       AND (e.status = 'CERRADO' OR sr.created_at < now() - make_interval(hours => $1))
     RETURNING sr.id, sr.event_id`,
    [timeoutHours],
  );
  return rows;
}

module.exports = {
  crear,
  buscarPorId,
  listarPorEvento,
  listarPorEventoYParticipante,
  resolver,
  marcarReproducida,
  cancelarSolicitudesColgadas,
};
