import 'package:flutter/material.dart';

import 'budsound_mark.dart';

/// Wrapper histórico — se mantiene con este nombre por compatibilidad (ver
/// DECISIONES_TECNICAS.md, rebranding "Cabina minimal") para no tener que
/// tocar las ~9 pantallas que ya lo instancian. Antes mostraba la imagen
/// `assets/brand/budsound_logo.jpg` con un halo; ahora delega en
/// [BudSoundMark], el isotipo dibujado a mano de la ruta minimal.
class GlowLogo extends StatelessWidget {
  const GlowLogo({
    super.key,
    this.size = 96,
    this.showWordmark = false,
  });

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return BudSoundMark(size: size, showWordmark: showWordmark);
  }
}
