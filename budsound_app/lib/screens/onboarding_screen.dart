import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_gradient_button.dart';

class _Paso {
  const _Paso({required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo;
  final String texto;
}

/// Recorrido express de 3 pasos que se muestra una sola vez, justo después
/// de que una cuenta nueva se registra (ver SessionService.marcarTutorialPendiente
/// y dónde se llama: RegisterScreen y LoginScreen tras completar el registro
/// con Google) — nunca en logins normales de una cuenta que ya existía.
/// Contenido distinto para DJ y Participante: cada uno ve solo los 3 pasos
/// que le importan a su rol, no un recorrido genérico de "la app sirve
/// para esto y esto otro".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.esDj});

  final bool esDj;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _pagina = 0;

  static const _pasosDj = [
    _Paso(
      icono: Icons.qr_code_2_rounded,
      titulo: 'Crea tu evento y comparte el QR',
      texto:
          'El público lo escanea desde su celular y empieza a pedirte canciones al instante.',
    ),
    _Paso(
      icono: Icons.timer_outlined,
      titulo: 'Acepta o rechaza en 7 minutos',
      texto:
          'Cada solicitud te espera en "En vivo", con una cuenta regresiva — si no respondes a tiempo, se cancela sola.',
    ),
    _Paso(
      icono: Icons.payments_outlined,
      titulo: 'Conecta Mercado Pago',
      texto:
          'Desde Perfil, para que las propinas de tus eventos lleguen directo a tu cuenta.',
    ),
  ];

  static const _pasosParticipante = [
    _Paso(
      icono: Icons.qr_code_scanner_rounded,
      titulo: 'Escanea el QR del evento',
      texto: 'Desde "En vivo", para unirte al DJ que estás viendo ahora mismo.',
    ),
    _Paso(
      icono: Icons.music_note_rounded,
      titulo: 'Pide tu canción',
      texto: 'Búscala y súmale una propina si quieres darle un empujón extra.',
    ),
    _Paso(
      icono: Icons.hourglass_top_rounded,
      titulo: 'Espera la respuesta del DJ',
      texto: 'Tiene hasta 7 minutos para aceptarla o rechazarla — tú ves el resultado al tiro.',
    ),
  ];

  List<_Paso> get _pasos => widget.esDj ? _pasosDj : _pasosParticipante;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _terminar() => Navigator.of(context).pop();

  void _siguiente() {
    if (_pagina == _pasos.length - 1) {
      _terminar();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ultimaPagina = _pagina == _pasos.length - 1;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: _terminar,
                    child: const Text('Omitir',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pasos.length,
                  onPageChanged: (i) => setState(() => _pagina = i),
                  itemBuilder: (context, i) => _vistaPaso(_pasos[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pasos.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _pagina ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _pagina
                                  ? AppColors.limeGreen
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    NeonGradientButton(
                      label: ultimaPagina ? 'Empezar' : 'Siguiente',
                      onPressed: _siguiente,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vistaPaso(_Paso paso) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.limeGreen.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(paso.icono, size: 48, color: AppColors.limeGreen),
          ),
          const SizedBox(height: 36),
          Text(
            paso.titulo,
            textAlign: TextAlign.center,
            style: AppTheme.fontDisplay(
              color: AppColors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            paso.texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.lavender, fontSize: 14.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
