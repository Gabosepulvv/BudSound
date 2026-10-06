const jwt = require('jsonwebtoken');
const env = require('../config/env');
const eventModel = require('../models/event.model');

// Cada evento tiene su propia sala ("event:<id>"). El DJ y los participantes
// conectados a un evento reciben los mismos cambios de la cola en vivo.
//
// Dos controles que antes faltaban (ver DECISIONES_TECNICAS.md, revisión de
// seguridad):
//   1. El handshake exige un JWT válido — antes un socket sin token igual
//      quedaba conectado (`socket.user = null`) y podía unirse a cualquier
//      sala.
//   2. `event:join` valida que el evento exista y, si quien se une es DJ,
//      que sea el dueño — antes cualquier socket conectado podía escuchar
//      la actividad en vivo de un evento ajeno con solo saber/adivinar su
//      id.
function registrarSockets(io) {
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('Token de autenticación faltante.'));
    try {
      socket.user = jwt.verify(token, env.jwtSecret);
      next();
    } catch (error) {
      next(new Error('Token inválido.'));
    }
  });

  io.on('connection', (socket) => {
    socket.on('event:join', async (eventId) => {
      if (typeof eventId !== 'string' || !eventId) return;
      try {
        const event = await eventModel.buscarPorId(eventId);
        if (!event) return;
        if (socket.user.role === 'DJ' && event.dj_id !== socket.user.sub) return;
        socket.join(`event:${event.id}`);
      } catch (error) {
        // Id con formato inválido u otro error de consulta: no se une a nada.
      }
    });

    socket.on('event:leave', (eventId) => {
      if (typeof eventId === 'string' && eventId) socket.leave(`event:${eventId}`);
    });
  });
}

module.exports = { registrarSockets };
