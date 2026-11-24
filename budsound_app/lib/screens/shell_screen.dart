import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/colorblind_mode_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import 'inicio_screen.dart';
import 'live_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';

/// Contenedor post-login. El Participante ve Inicio, En vivo y Perfil; el
/// DJ no tiene "Inicio" — su saludo y el estado de su evento ya viven en
/// "En vivo" (`DjEventsScreen`), y su historial/estadísticas en Perfil, así
/// que una tercera pestaña que solo repetía esa misma info sobraba.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;
  // Cambia cada vez que se vuelve a "Inicio" para forzar que se recree y
  // recargue su estado (el IndexedStack mantiene vivas las otras pestañas,
  // así que sin esto "Inicio" quedaría mostrando datos viejos si el evento
  // se unió/creó/cerró mientras se estaba en otra pestaña). Sin efecto para
  // el DJ, que no tiene esta pestaña.
  int _inicioTick = 0;

  bool get _esDj => SessionService.instance.rol == UserRole.dj;

  @override
  void initState() {
    super.initState();
    // Después del primer frame (no en initState directo: todavía no hay
    // un Navigator listo para empujar una pantalla nueva encima) — una
    // sola vez por cuenta nueva, ver SessionService.marcarTutorialPendiente.
    if (SessionService.instance.tutorialPendiente) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarTutorial());
    }
  }

  Future<void> _mostrarTutorial() async {
    await SessionService.instance.marcarTutorialVisto();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(esDj: _esDj),
        fullscreenDialog: true,
      ),
    );
  }

  void _irAEnVivo() => setState(() => _indice = _esDj ? 0 : 1);

  void _cambiarPestana(int indice) {
    setState(() {
      _indice = indice;
      if (!_esDj && indice == 0) _inicioTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final esDj = _esDj;
    // Inicio/En vivo/Perfil quedan vivos en el IndexedStack (nunca se
    // destruyen al cambiar de pestaña) — sin este listener, tocar "Modo
    // daltónico" en Perfil no se reflejaría en las otras pestañas hasta
    // salir y volver a entrar a la app. Los hijos tampoco pueden ser
    // `const` acá: una instancia const es la MISMA cada vez, así que
    // Flutter nunca volvería a construirla aunque este build() se repita.
    return ListenableBuilder(
      listenable: ColorblindModeService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _indice,
            children: esDj
                // ignore: prefer_const_constructors
                ? [LiveScreen(), ProfileScreen()]
                : [
                    InicioScreen(
                        key: ValueKey(_inicioTick), onIrAEnVivo: _irAEnVivo),
                    // ignore: prefer_const_constructors
                    LiveScreen(),
                    // ignore: prefer_const_constructors
                    ProfileScreen(),
                  ],
          ),
          bottomNavigationBar: _BarraFlotante(
            esDj: esDj,
            indiceSeleccionado: _indice,
            onSeleccionar: _cambiarPestana,
          ),
        );
      },
    );
  }
}

/// Barra de navegación plana, ancho completo — sin línea superior. El tab
/// activo se marca con un punto azul de 5px sobre su etiqueta (nunca una
/// franja de color ni un círculo relleno detrás del ícono).
class _BarraFlotante extends StatelessWidget {
  const _BarraFlotante({
    required this.esDj,
    required this.indiceSeleccionado,
    required this.onSeleccionar,
  });

  final bool esDj;
  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;

  static const _itemsParticipante = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.podcasts_rounded, 'En vivo'),
    (Icons.person_rounded, 'Perfil'),
  ];

  static const _itemsDj = [
    (Icons.podcasts_rounded, 'En vivo'),
    (Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = esDj ? _itemsDj : _itemsParticipante;
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                _botonTab(
                  icono: items[i].$1,
                  etiqueta: items[i].$2,
                  activo: i == indiceSeleccionado,
                  onTap: () => onSeleccionar(i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonTab({
    required IconData icono,
    required String etiqueta,
    required bool activo,
    required VoidCallback onTap,
  }) {
    final color = activo ? AppColors.limeGreen : AppColors.muted;
    return Semantics(
      label: etiqueta,
      selected: activo,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: activo ? 1 : 0,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.limeGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
