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
  app.use(express.json());
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
