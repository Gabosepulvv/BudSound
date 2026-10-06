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

  // Un ApiError es siempre intencional (el código eligió ese mensaje a
  // propósito para mostrarlo, pase lo que pase con su status — ej. un 503
  // "todavía no está configurado"), así que su mensaje siempre es seguro de
  // mostrar. Cualquier OTRO error (uno no esperado, de `pg`, de una
  // librería, un bug) puede traer detalles internos (nombres de
  // tabla/columna, rutas de archivo) en su mensaje — ese se loguea acá pero
  // nunca se manda al cliente.
  if (!(err instanceof ApiError)) {
    console.error(err);
    return res.status(status).json({ error: 'Error interno del servidor.' });
  }
  res.status(status).json({ error: err.message || 'Error interno del servidor.' });
}

module.exports = { ApiError, notFoundHandler, errorHandler };
