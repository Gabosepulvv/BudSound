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
          extendBody: true,
          body: IndexedStack(
            index: _indice,
            children: esDj
                ? const [LiveScreen(), ProfileScreen()]
                : [
                    InicioScreen(
                        key: ValueKey(_inicioTick), onIrAEnVivo: _irAEnVivo),
                    const LiveScreen(),
                    const ProfileScreen(),
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

/// Barra de navegación como píldora flotante, no una franja que ocupa todo
/// el ancho — el acento solo se nota en el ícono activo (un círculo
/// relleno detrás), nada de indicador ancho ni franja de color.
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
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
        ),
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
    );
  }

  Widget _botonTab({
    required IconData icono,
    required String etiqueta,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: etiqueta,
      selected: activo,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: activo ? AppColors.limeGreen : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icono,
            color: activo ? AppColors.onLime : AppColors.muted,
            size: 24,
          ),
        ),
      ),
    );
  }
}
