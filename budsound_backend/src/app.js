const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const env = require('./config/env');
const routes = require('./routes');
const { paginaCheckout } = require('./controllers/checkout.controller');
const { paginaDisplay } = require('./controllers/display.controller');
const { paginaInicio, paginaPrivacidad } = require('./controllers/pages.controller');
const { notFoundHandler, errorHandler } = require('./middleware/error.middleware');

function crearApp(io) {
  const app = express();

  // Sin esto, Express ve la IP del proxy de Railway en TODAS las
  // peticiones (nunca la del celular/navegador real) — el limitador de
  // intentos de auth.routes.js (pensado por-IP) termina contando como si
  // todo el tráfico viniera de una sola persona, y basta con unas pocas
  // peticiones de cualquier origen para bloquear a alguien más. `1` porque
  // Railway es un solo salto de proxy por delante de este backend.
  if (env.nodeEnv === 'production') {
    app.set('trust proxy', 1);
  }

  app.use(helmet());
  app.use(cors({ origin: env.corsOrigin }));
  // Límite subido de 100kb (default de Express) a 4mb: tanto la foto de
  // perfil (ver AVATAR_MAX_LENGTH, 2.8MB) como la imagen de un evento (ver
  // IMAGEN_EVENTO_MAX_LENGTH, 3.5MB) viajan como base64 dentro del JSON, no
  // como multipart — este límite tiene que quedar por encima del más
  // grande de los dos (con margen para el resto del body), si no Express
  // la rechaza con un 413 genérico antes de que la validación propia de
  // cada controlador llegue a correr.
  app.use(express.json({ limit: '4mb' }));
  // El único que manda datos como formulario HTML (`x-www-form-urlencoded`,
  // no JSON) es el formulario de "nueva contraseña" que abre el link del
  // correo de recuperación (`paginaRestablecer`/`confirmarRestablecer` en
  // auth.controller.js) — es una página de navegador, no un fetch de la app.
  app.use(express.urlencoded({ extended: true }));
  app.use(morgan(env.nodeEnv === 'production' ? 'combined' : 'dev'));

  // Expone Socket.io a los controladores (req.io) para emitir eventos
  // en tiempo real sin acoplar cada controlador a la instancia global.
  app.use((req, res, next) => {
    req.io = io;
    next();
  });

  // Página HTML servida para el WebView de la app (no es parte de la API
  // JSON) — ahí vive el formulario de tarjeta de MercadoPago para tokenizar
  // el pago de una propina (ver checkout.controller.js).
  app.post('/pay/checkout', paginaCheckout);

  // Página pública (sin login) para mostrar el QR en grande en una TV o
  // tablet del local — el código ya es público por diseño (ver
  // display.controller.js), así que no necesita autenticación.
  app.get('/display/:code', paginaDisplay);

  // Páginas públicas mínimas, solo para cumplir el requisito de Google
  // Cloud Console (pantalla de consentimiento OAuth, "URL de página
  // principal" y "URL de política de privacidad") al publicar la app en
  // modo producción externa — ver pages.controller.js.
  app.get('/', paginaInicio);
  app.get('/privacy', paginaPrivacidad);

  app.use('/api', routes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = crearApp;
