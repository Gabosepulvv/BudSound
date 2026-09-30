import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/event_service.dart';
import '../theme/app_colors.dart';
import '../widgets/budsound_text_field.dart';
import '../widgets/neon_gradient_button.dart';
import 'dj_queue_screen.dart';

/// Vista del DJ en la pestaña "En vivo": sus eventos y crear uno nuevo.
class DjEventsScreen extends StatefulWidget {
  const DjEventsScreen({super.key});

  @override
  State<DjEventsScreen> createState() => _DjEventsScreenState();
}

class _DjEventsScreenState extends State<DjEventsScreen> {
  final _eventService = EventService();
  late Future<List<EventModel>> _eventosFuture;

  @override
  void initState() {
    super.initState();
    _eventosFuture = _eventService.misEventos();
  }

  void _recargar() {
    // Cuerpo de bloque a propósito: `setState(() => _eventosFuture = ...)`
    // hace que el closure "devuelva" el Future de la asignación, y
    // setState lanza un assert en tiempo de ejecución si su callback
    // devuelve un Future (piensa que olvidaste un await).
    setState(() {
      _eventosFuture = _eventService.misEventos();
    });
  }

  Future<void> _crearEvento() async {
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Nuevo evento',
          style: TextStyle(color: AppColors.white),
        ),
        content: BudsoundTextField(
          controller: controller,
          label: 'Nombre del evento',
          hint: 'Ej. Noche Neon',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (nombre == null || nombre.isEmpty) return;

    try {
      final evento = await _eventService.crear(nombre);
      if (!mounted) return;
      _recargar();
      _abrirCola(evento);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _abrirCola(EventModel evento) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DjQueueScreen(evento: evento)))
        .then((_) => _recargar());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tus eventos',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Crea un evento para generar el QR y recibir solicitudes en vivo.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              NeonGradientButton(
                  label: 'Crear evento', onPressed: _crearEvento),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<EventModel>>(
            future: _eventosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.neonBlue),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _recargar,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                );
              }
              final eventos = snapshot.data ?? [];
              if (eventos.isEmpty) {
                return const Center(
                  child: Text(
                    'Todavía no has creado ningún evento.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _recargar(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: eventos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _tarjeta(eventos[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(EventModel evento) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirCola(evento),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: evento.activo ? AppColors.neonBlue : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  evento.activo
                      ? Icons.qr_code_2_rounded
                      : Icons.lock_outline_rounded,
                  color: AppColors.neonBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evento.nombre,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código ${evento.code} · ${evento.activo ? 'Activo' : 'Cerrado'}',
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
