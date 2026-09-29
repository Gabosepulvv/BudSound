const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const env = require('./config/env');
const routes = require('./routes');
const { notFoundHandler, errorHandler } = require('./middleware/error.middleware');

function crearApp(io) {
  const app = express();

  app.use(helmet());
  app.use(cors({ origin: env.corsOrigin }));
  // Límite subido de 100kb (default de Express) a 3mb: la foto de perfil
  // viaja como base64 dentro del JSON, no como multipart.
  app.use(express.json({ limit: '3mb' }));
  app.use(morgan(env.nodeEnv === 'production' ? 'combined' : 'dev'));

  // Expone Socket.io a los controladores (req.io) para emitir eventos
  // en tiempo real sin acoplar cada controlador a la instancia global.
  app.use((req, res, next) => {
    req.io = io;
    next();
  });

  app.use('/api', routes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = crearApp;
