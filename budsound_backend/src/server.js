const http = require('http');
const { Server } = require('socket.io');
const env = require('./config/env');
const crearApp = require('./app');
const { registrarSockets } = require('./sockets');
const { iniciarLimpiezaPeriodica } = require('./jobs/cleanupRequests');

const httpServer = http.createServer();
const io = new Server(httpServer, { cors: { origin: env.corsOrigin } });
registrarSockets(io);

const app = crearApp(io);
httpServer.on('request', app);

httpServer.listen(env.port, () => {
  console.log(`BudSound backend escuchando en http://localhost:${env.port}`);
  iniciarLimpiezaPeriodica(io);
});
