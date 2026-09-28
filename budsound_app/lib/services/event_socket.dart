import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../core/api_config.dart';
import 'session_service.dart';

/// Conexión de Socket.io a la sala de un evento (`event:<id>` en el
/// backend). Los callbacks solo avisan que "algo cambió"; quien escucha
/// decide si refresca la cola por REST, evitando duplicar el parseo de
/// modelos entre el socket y las respuestas HTTP.
class EventSocket {
  EventSocket(this.eventId);

  final String eventId;
  socket_io.Socket? _socket;

  void conectar({
    void Function()? onSolicitudCreada,
    void Function()? onSolicitudResuelta,
    void Function()? onPagoAprobado,
    void Function()? onEventoCerrado,
  }) {
    final socket = socket_io.io(
      ApiConfig.socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': SessionService.instance.jwt})
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) => socket.emit('event:join', eventId));
    if (onSolicitudCreada != null) {
      socket.on('request:created', (_) => onSolicitudCreada());
    }
    if (onSolicitudResuelta != null) {
      socket.on('request:resolved', (_) => onSolicitudResuelta());
    }
    if (onPagoAprobado != null) {
      socket.on('payment:approved', (_) => onPagoAprobado());
    }
    if (onEventoCerrado != null) {
      socket.on('event:closed', (_) => onEventoCerrado());
    }

    socket.connect();
    _socket = socket;
  }

  void desconectar() {
    _socket?.emit('event:leave', eventId);
    _socket?.dispose();
    _socket = null;
  }
}
