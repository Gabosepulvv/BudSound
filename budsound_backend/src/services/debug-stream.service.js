// Panel de diagnóstico en vivo: cualquier parte del backend puede avisar un
// evento con `emitir(tipo, datos)` y llega al instante a quien tenga abierto
// GET /api/debug/stream (ver debug.routes.js) — pensado para ver en tiempo
// real qué pasa con un pago mientras se prueba desde la app, sin tener que
// ir a revisar los logs de Railway a mano cada vez.
const clientes = new Set();

function conectar(res) {
  clientes.add(res);
}

function desconectar(res) {
  clientes.delete(res);
}

function emitir(tipo, datos) {
  const payload = JSON.stringify({ tipo, datos, timestamp: new Date().toISOString() });
  for (const res of clientes) {
    res.write(`data: ${payload}\n\n`);
  }
}

module.exports = { conectar, desconectar, emitir };
