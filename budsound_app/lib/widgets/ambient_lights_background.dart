import 'package:flutter/material.dart';

/// Wrapper vacío — se mantiene por compatibilidad (ver
/// DECISIONES_TECNICAS.md, rebranding "Cabina minimal") para no tener que
/// tocar cada pantalla que ya lo instancia. Antes pintaba una mancha de luz
/// violeta ambiental; la ruta minimal usa fondo plano sin glow, así que
/// ahora no dibuja nada.
class AmbientLightsBackground extends StatelessWidget {
  const AmbientLightsBackground({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
