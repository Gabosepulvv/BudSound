import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../models/itunes_track.dart';
import '../models/user_role.dart';
import '../services/itunes_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glow_logo.dart';

/// Shell post-login: catálogo iTunes (base para Descubrir y otras vistas).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _busqueda = TextEditingController();
  final _itunes = ItunesService();
  List<ItunesTrack> _pistas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDestacados();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarDestacados() async {
    await _buscar('electronic house dj');
  }

  Future<void> _buscar(String termino) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pistas = await _itunes.buscarCanciones(termino);
      if (!mounted) return;
      setState(() {
        _pistas = pistas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el catálogo de iTunes.';
        _cargando = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await SessionService.instance.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = SessionService.instance;
    final saludo = sesion.nombreVisible ?? sesion.email ?? 'tú';
    final esDj = sesion.rol == UserRole.dj;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            GlowLogo(size: 34),
            SizedBox(width: 10),
            Text('Descubrir'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esDj ? 'Hola, $saludo' : 'Bienvenido, $saludo',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Catálogo vía iTunes Search API — base para las próximas vistas.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _busqueda,
                  style: const TextStyle(color: AppColors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => _buscar(v.isEmpty ? 'electronic' : v),
                  decoration: InputDecoration(
                    hintText: 'Buscar canciones, DJs o géneros',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        _buscar(
                          _busqueda.text.trim().isEmpty
                              ? 'electronic'
                              : _busqueda.text,
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonBlue),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cargarDestacados,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_pistas.isEmpty) {
      return const Center(
        child: Text('Sin resultados en iTunes para esa búsqueda.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _pistas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final pista = _pistas[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                pista.artworkGrande,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.album_rounded),
                ),
              ),
            ),
            title: Text(
              pista.trackName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${pista.artistName} · ${pista.genre}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
            trailing: pista.previewUrl == null
                ? null
                : const Icon(
                    Icons.play_circle_outline_rounded,
                    color: AppColors.neonBlue,
                  ),
          ),
        );
      },
    );
  }
}
