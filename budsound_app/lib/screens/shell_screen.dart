import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/now_playing_bar.dart';
import 'home_screen.dart';
import 'live_screen.dart';
import 'profile_screen.dart';

/// Contenedor post-login: Descubrir, En vivo y Perfil.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _indice,
        children: const [
          HomeScreen(),
          LiveScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NowPlayingBar(),
          NavigationBar(
            selectedIndex: _indice,
            onDestinationSelected: (i) => setState(() => _indice = i),
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.neonBlue.withOpacity(0.25),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Descubrir',
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
        ],
      ),
    );
  }
}
