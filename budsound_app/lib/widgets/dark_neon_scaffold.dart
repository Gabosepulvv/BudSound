import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo plano negro mate — wrapper que se mantiene por compatibilidad (ver
/// DECISIONES_TECNICAS.md, rebranding "Cabina minimal") para no tener que
/// tocar cada pantalla que ya lo usa. Antes tenía una mancha de glow violeta
/// flotando; la ruta minimal usa fondo plano sin glow.
class DarkNeonScaffold extends StatelessWidget {
  const DarkNeonScaffold({
    super.key,
    required this.child,
    this.appBar,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: SafeArea(child: child),
    );
  }
}
