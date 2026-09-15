import '../models/live_session.dart';
import '../models/user_role.dart';
import 'session_service.dart';

/// Catálogo simulado de sesiones. Sustituible por API cuando exista backend.
class LiveCatalog {
  const LiveCatalog();

  List<LiveSession> sesiones() {
    final sesion = SessionService.instance;
    final propias = <LiveSession>[];

    if (sesion.rol == UserRole.dj) {
      propias.add(
        LiveSession(
          id: 'own-booth',
          djName: sesion.nombreVisible ?? 'Tu booth',
          titulo: 'Booth listo — pulsa para ir en vivo',
          ciudad: 'Tu ciudad',
          genero: 'House',
          oyentes: 0,
          enVivo: false,
          venue: 'Budsound Studio',
        ),
      );
    }

    return [
      ...propias,
      const LiveSession(
        id: 'neon-01',
        djName: 'DJ Neon',
        titulo: 'Afterhours peak time',
        ciudad: 'CDMX',
        genero: 'Techno',
        oyentes: 1284,
        enVivo: true,
        venue: 'Bunker',
      ),
      const LiveSession(
        id: 'luna-02',
        djName: 'Luna Wave',
        titulo: 'Sunset melodic',
        ciudad: 'Guadalajara',
        genero: 'Melodic House',
        oyentes: 642,
        enVivo: true,
        venue: 'Terraza 22',
      ),
      const LiveSession(
        id: 'pulse-03',
        djName: 'Pulse Theory',
        titulo: 'Warehouse warm-up',
        ciudad: 'Monterrey',
        genero: 'Minimal',
        oyentes: 0,
        enVivo: false,
        venue: 'Nave Norte',
      ),
      const LiveSession(
        id: 'kairo-04',
        djName: 'Kairo',
        titulo: 'Latin bass lab',
        ciudad: 'Medellín',
        genero: 'Bass',
        oyentes: 891,
        enVivo: true,
        venue: 'Club 4AM',
      ),
    ];
  }
}
