import 'package:flutter/material.dart';

import '../models/live_session.dart';
import '../models/user_role.dart';
import '../services/live_catalog.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glow_logo.dart';

/// Sesiones en vivo (simulado) según el rol Público / DJ.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _catalogo = const LiveCatalog();
  late List<LiveSession> _sesiones;

  @override
  void initState() {
    super.initState();
    _sesiones = _catalogo.sesiones();
  }

  void _abrirSesion(LiveSession sesion) {
    final esDj = SessionService.instance.rol == UserRole.dj;
    final propia = sesion.id == 'own-booth';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cobalt,
        content: Text(
          propia && esDj
              ? 'Booth listo. El streaming en vivo se conectará al backend.'
              : sesion.enVivo
                  ? 'Entrando a ${sesion.titulo} de ${sesion.djName}…'
                  : '${sesion.djName} aún no está en el booth.',
        ),
      ),
    );
  }

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            esDj
                ? 'Tu booth y la escena de esta noche'
                : 'DJs tocando ahora',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Salas simuladas — se reemplazan cuando exista el servidor de streaming.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._sesiones.map(_tarjeta),
        ],
      ),
    );
  }

  Widget _tarjeta(LiveSession sesion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _abrirSesion(sesion),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sesion.enVivo ? AppColors.neonBlue : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    sesion.enVivo
                        ? Icons.graphic_eq_rounded
                        : Icons.headphones_outlined,
                    color: AppColors.neonBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (sesion.enVivo) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              sesion.djName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sesion.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.lavender),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sesion.ciudad}${sesion.venue != null ? ' · ${sesion.venue}' : ''} · ${sesion.genero}'
                        '${sesion.enVivo ? ' · ${sesion.oyentes} oyentes' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
