const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');

async function migrar() {
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await pool.query(schema);
  console.log('Esquema aplicado correctamente.');
  await pool.end();
}

migrar().catch((error) => {
  console.error('Error aplicando el esquema:', error.message);
  process.exit(1);
});
