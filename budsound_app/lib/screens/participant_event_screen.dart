import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../models/itunes_track.dart';
import '../models/song_request_model.dart';
import '../services/event_socket.dart';
import '../services/request_service.dart';
import '../services/song_service.dart';
import '../theme/app_colors.dart';
import '../widgets/neon_gradient_button.dart';

/// Buscar canción y pedirla (con propina opcional) dentro de un evento, y
/// ver el estado de las propias solicitudes en vivo.
class ParticipantEventScreen extends StatefulWidget {
  const ParticipantEventScreen({super.key, required this.evento});

  final EventModel evento;

  @override
  State<ParticipantEventScreen> createState() => _ParticipantEventScreenState();
}

class _ParticipantEventScreenState extends State<ParticipantEventScreen>
    with SingleTickerProviderStateMixin {
  final _songService = SongService();
  final _requestService = RequestService();
  final _busqueda = TextEditingController();
  late final EventSocket _socket;
  late final TabController _tabController;

  List<ItunesTrack> _resultados = [];
  List<SongRequestModel> _misSolicitudes = [];
  final Set<String> _propinasPagadas = {};
  bool _buscando = false;
  bool _conectado = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _socket = EventSocket(widget.evento.id)
      ..conectar(
        onSolicitudResuelta: _cargarMisSolicitudes,
        onPagoAprobado: _cargarMisSolicitudes,
        onConectado: () => setState(() => _conectado = true),
        onDesconectado: () => setState(() => _conectado = false),
      );
    _cargarMisSolicitudes();
  }

  @override
  void dispose() {
    _socket.desconectar();
    _busqueda.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _buscar(String termino) async {
    if (termino.trim().isEmpty) return;
    setState(() => _buscando = true);
    try {
      final resultados = await _songService.buscar(termino);
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _buscando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _cargarMisSolicitudes() async {
    try {
      final solicitudes =
          await _requestService.misSolicitudes(widget.evento.id);
      if (!mounted) return;
      setState(() => _misSolicitudes = solicitudes);
    } catch (_) {
      // La cola sigue funcionando aunque falle un refresh puntual.
    }
  }

  Future<void> _pedirCancion(ItunesTrack pista) async {
    final eleccion = await _elegirMonto(pista);
    if (eleccion == null) return;
    final (monto, terminosAceptados) = eleccion;

    try {
      await _requestService.crear(
        eventId: widget.evento.id,
        pista: pista,
        montoClp: monto,
        terminosAceptados: terminosAceptados,
      );
      await _cargarMisSolicitudes();
      if (!mounted) return;
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitud enviada al DJ'),
            backgroundColor: AppColors.cobalt),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  /// Devuelve (monto, aceptóTérminos) o null si canceló. Con propina, el
  /// checkbox de Términos y Condiciones es obligatorio: una vez que el DJ
  /// acepta la solicitud no hay devolución (ver CLAUDE.md, riesgo "El
  /// participante pide la devolución del dinero").
  Future<(int, bool)?> _elegirMonto(ItunesTrack pista) async {
    final controller = TextEditingController();
    var aceptaTerminos = false;
    return showModalBottomSheet<(int, bool)>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                pista.trackName,
                style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              Text(pista.artistName,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              const Text(
                'Propina opcional para el DJ (\$500 - \$20.000 CLP). '
                'No garantiza que suene, es solo un incentivo.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.white),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Monto en CLP (opcional)',
                  hintText: '0',
                ),
              ),
              if ((int.tryParse(controller.text.trim()) ?? 0) > 0) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: aceptaTerminos,
                  onChanged: (v) => setState(() => aceptaTerminos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.neonBlue,
                  title: const Text(
                    'Entiendo que si el DJ acepta la propina, no hay devolución.',
                    style: TextStyle(color: AppColors.lavender, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              NeonGradientButton(
                label: 'Enviar solicitud',
                onPressed: () {
                  final monto = int.tryParse(controller.text.trim()) ?? 0;
                  if (monto != 0 && (monto < 500 || monto > 20000)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'El monto debe ser entre \$500 y \$20.000 CLP.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  if (monto > 0 && !aceptaTerminos) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Acepta los Términos y Condiciones para enviar una propina.'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop((monto, aceptaTerminos));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pagarPropina(SongRequestModel solicitud) async {
    try {
      await _requestService.simularAprobacionDePago(solicitud.id);
      if (!mounted) return;
      setState(() => _propinasPagadas.add(solicitud.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pago aprobado (simulado)'),
            backgroundColor: AppColors.cobalt),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.evento.nombre),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Buscar canción'),
            Tab(text: 'Mis solicitudes'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_conectado) _bannerSinConexion(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_tabBuscar(), _tabMisSolicitudes()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerSinConexion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.danger.withOpacity(0.15),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin conexión — reconectando…',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBuscar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _busqueda,
            style: const TextStyle(color: AppColors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: _buscar,
            decoration: InputDecoration(
              hintText: 'Buscar canción o artista',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () => _buscar(_busqueda.text),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
        ),
        if (_buscando)
          const Expanded(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.neonBlue)))
        else
          Expanded(
            child: _resultados.isEmpty
                ? const Center(
                    child: Text('Busca una canción para pedirla.',
                        style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final pista = _resultados[index];
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          onTap: () => _pedirCancion(pista),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              pista.artworkUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.album_rounded),
                            ),
                          ),
                          title: Text(
                            pista.trackName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            pista.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          trailing: const Icon(Icons.add_circle_outline_rounded,
                              color: AppColors.neonBlue),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _tabMisSolicitudes() {
    if (_misSolicitudes.isEmpty) {
      return const Center(
        child: Text('Todavía no has pedido ninguna canción.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarMisSolicitudes,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _misSolicitudes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _tarjetaSolicitud(_misSolicitudes[index]),
      ),
    );
  }

  Widget _tarjetaSolicitud(SongRequestModel solicitud) {
    final color = solicitud.aceptada
        ? AppColors.neonBlue
        : solicitud.rechazada
            ? AppColors.danger
            : solicitud.cancelada
                ? AppColors.muted
                : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  solicitud.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w700),
                ),
                Text(
                  solicitud.artista,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  solicitud.pendiente
                      ? 'Esperando al DJ'
                      : solicitud.aceptada
                          ? (solicitud.reproducida ? 'Reproducida' : 'Aceptada')
                          : solicitud.cancelada
                              ? 'Cancelada (sin respuesta a tiempo)'
                              : 'Rechazada',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          if (solicitud.aceptada && solicitud.tienePropina)
            _propinasPagadas.contains(solicitud.id)
                ? const Text('Pagado',
                    style: TextStyle(
                        color: AppColors.neonBlue, fontWeight: FontWeight.w700))
                : TextButton(
                    onPressed: () => _pagarPropina(solicitud),
                    child: const Text('Pagar propina'),
                  ),
        ],
      ),
    );
  }
}
