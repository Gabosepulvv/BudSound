import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'inicio_screen.dart';
import 'live_screen.dart';
import 'profile_screen.dart';

/// Contenedor post-login: Inicio, En vivo y Perfil.
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
  // se unió/creó/cerró mientras se estaba en otra pestaña).
  int _inicioTick = 0;

  void _irAEnVivo() => setState(() => _indice = 1);

  void _cambiarPestana(int indice) {
    setState(() {
      _indice = indice;
      if (indice == 0) _inicioTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _indice,
        children: [
          InicioScreen(key: ValueKey(_inicioTick), onIrAEnVivo: _irAEnVivo),
          const LiveScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _cambiarPestana,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.limeGreen.withOpacity(0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.podcasts_outlined),
            selectedIcon: Icon(Icons.podcasts_rounded),
            label: 'En vivo',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
