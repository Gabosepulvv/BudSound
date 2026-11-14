/// Formatea un monto en pesos chilenos con separador de miles a mano (sin
/// paquete `intl`) — ej. 125000 -> "$125.000". Antes cada pantalla de dinero
/// (propinas, resumen del DJ, estadísticas de Perfil) traía su propia copia
/// de esto, y una de ellas (`ParticipantEventScreen`) asumía que todo monto
/// era múltiplo exacto de 1000, mostrando "$1.650" como "$1.000".
String formatearClp(num valor) {
  final texto = valor.toInt().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return '\$$buffer';
}
