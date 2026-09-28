const ALFABETO = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin caracteres ambiguos (0/O, 1/I)

function generarCodigoEvento(longitud = 6) {
  let codigo = '';
  for (let i = 0; i < longitud; i += 1) {
    codigo += ALFABETO[Math.floor(Math.random() * ALFABETO.length)];
  }
  return codigo;
}

module.exports = { generarCodigoEvento };
