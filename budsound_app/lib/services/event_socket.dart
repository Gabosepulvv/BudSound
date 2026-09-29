import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../core/api_config.dart';
import 'session_service.dart';

/// Conexión de Socket.io a la sala de un evento (`event:<id>` en el
/// backend). Los callbacks solo avisan que "algo cambió"; quien escucha
/// decide si refresca la cola por REST, evitando duplicar el parseo de
/// modelos entre el socket y las respuestas HTTP.
///
/// La reconexión automática queda explícita a propósito: en el lugar del
/// evento cientos de celulares comparten la misma WiFi/red móvil y los
/// cortes de un par de segundos son esperables (ver CLAUDE.md, riesgo
/// "Congestión de red y desconexión en el evento").
class EventSocket {
  EventSocket(this.eventId);

  final String eventId;
  socket_io.Socket? _socket;

  void conectar({
    void Function()? onSolicitudCreada,
    void Function()? onSolicitudResuelta,
    void Function()? onSolicitudReproducida,
    void Function()? onPagoAprobado,
    void Function()? onEventoCerrado,
    void Function()? onConectado,
    void Function()? onDesconectado,
  }) {
    final socket = socket_io.io(
      ApiConfig.socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': SessionService.instance.jwt})
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      socket.emit('event:join', eventId);
      onConectado?.call();
    });
    // onReconnect no siempre re-emite "connect" en todas las plataformas,
    // así que unimos la sala también acá para no perder la sala tras un corte.
    socket.onReconnect((_) => socket.emit('event:join', eventId));
    socket.onDisconnect((_) => onDesconectado?.call());

    if (onSolicitudCreada != null) {
      socket.on('request:created', (_) => onSolicitudCreada());
    }
    if (onSolicitudResuelta != null) {
      socket.on('request:resolved', (_) => onSolicitudResuelta());
    }
    if (onSolicitudReproducida != null) {
      socket.on('request:played', (_) => onSolicitudReproducida());
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
