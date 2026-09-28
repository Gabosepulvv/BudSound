const { Pool } = require('pg');
const env = require('./env');

const pool = new Pool({ connectionString: env.databaseUrl });

// Un cliente inactivo puede perder la conexión (ej. la BD se reinicia) sin
// que ninguna query esté en curso; sin este handler, ese error no capturado
// tumba el proceso completo.
pool.on('error', (error) => {
  console.error('Error inesperado en el pool de PostgreSQL:', error.message);
});

module.exports = { pool };
