const jwt = require('jsonwebtoken');
const env = require('../config/env');

// Cada evento tiene su propia sala ("event:<id>"). El DJ y los participantes
// conectados a un evento reciben los mismos cambios de la cola en vivo.
function registrarSockets(io) {
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      socket.user = token ? jwt.verify(token, env.jwtSecret) : null;
      next();
    } catch (error) {
      next(new Error('Token inválido.'));
    }
  });

  io.on('connection', (socket) => {
    socket.on('event:join', (eventId) => {
      socket.join(`event:${eventId}`);
    });

    socket.on('event:leave', (eventId) => {
      socket.leave(`event:${eventId}`);
    });
  });
}

module.exports = { registrarSockets };
