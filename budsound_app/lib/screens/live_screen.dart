import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glow_logo.dart';
import 'dj_events_screen.dart';
import 'participant_join_screen.dart';

/// Punto de entrada de "En vivo": el DJ administra sus eventos, el
/// Participante se une a uno vía QR o código.
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final esDj = SessionService.instance.rol == UserRole.dj;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            GlowLogo(size: 34),
            SizedBox(width: 10),
            Text('En vivo'),
          ],
        ),
      ),
      // Sin `const` a propósito: si fueran const, Flutter los trataría como
      // el mismo objeto en cada rebuild y nunca reconstruiría esta rama —
      // por eso el modo daltónico (ColorblindModeService, ver
      // ShellScreen._ShellScreenState.build) no se reflejaba acá aunque sí
      // en Inicio y Perfil.
      body: esDj ? const DjEventsScreen() : const ParticipantJoinScreen(),
    );
  }
}
