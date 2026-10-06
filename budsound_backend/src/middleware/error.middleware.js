class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function notFoundHandler(req, res) {
  res.status(404).json({ error: 'Recurso no encontrado.' });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const status = err.status || 500;
  if (status >= 500) {
    // Un error no esperado (ej. de `pg`, de una librería, un bug) puede
    // traer detalles internos (nombres de tabla/columna, rutas de
    // archivo) en su mensaje — eso se loguea acá pero nunca se manda al
    // cliente. Los errores controlados (ApiError, status < 500) sí usan su
    // propio mensaje porque están pensados para mostrarse.
    console.error(err);
    return res.status(status).json({ error: 'Error interno del servidor.' });
  }
  res.status(status).json({ error: err.message || 'Error interno del servidor.' });
}

module.exports = { ApiError, notFoundHandler, errorHandler };
