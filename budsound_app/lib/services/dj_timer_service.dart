/// Estado del temporizador de set del DJ (ver `DjQueueScreen._tarjetaTemporizador`).
///
/// Vive en un singleton, no en el `State` de la pantalla, para que siga
/// corriendo si el DJ sale de la cola (ej. revisa "Perfil") y vuelve — antes
/// estaba en campos locales de `_DjQueueScreenState` y se perdía con cada
/// `dispose()`. Sigue siendo puramente local al dispositivo: no se guarda en
/// disco ni se manda al backend, así que un cierre real de la app sí lo
/// reinicia (aceptable: es una ayuda de pulso para la sesión actual).
///
/// Guarda a qué evento pertenece (`_eventoId`): sin esto, cerrar un evento
/// con el temporizador corriendo y crear uno nuevo hacía que el nuevo
/// evento "heredara" la cuenta regresiva del anterior, porque el singleton
/// no tenía forma de saber que ya no correspondía. Todo lo demás (pausa,
/// tiempo restante) sigue siendo un solo temporizador a la vez — un DJ no
/// puede tener dos eventos activos (ver decisión 34), así que no hace
/// falta guardar uno por evento, alcanza con invalidar el que ya no aplica.
class DjTimerService {
  DjTimerService._();
  static final DjTimerService instance = DjTimerService._();

  String? _eventoId;
  Duration? _duracionTotal;
  DateTime? _finPrevisto;
  Duration? _restantePausado;
  bool _pausado = false;

  /// True solo si hay un temporizador activo Y pertenece a este evento —
  /// cualquier pantalla que muestre el temporizador de un evento distinto
  /// (uno nuevo, o uno viejo del historial) debe usar esto, nunca mirar el
  /// estado interno sin filtrar por el evento que está mostrando.
  bool activoPara(String eventoId) =>
      _eventoId == eventoId && _duracionTotal != null;

  bool get pausado => _pausado;

  Duration get restante {
    if (_duracionTotal == null) return Duration.zero;
    if (_pausado) return _restantePausado ?? Duration.zero;
    final restante = _finPrevisto!.difference(DateTime.now());
    return restante.isNegative ? Duration.zero : restante;
  }

  void iniciar(String eventoId, Duration duracion) {
    _eventoId = eventoId;
    _duracionTotal = duracion;
    _finPrevisto = DateTime.now().add(duracion);
    _restantePausado = null;
    _pausado = false;
  }

  void pausar() {
    if (_pausado || _duracionTotal == null) return;
    _restantePausado = restante;
    _pausado = true;
  }

  void reanudar() {
    if (!_pausado || _restantePausado == null) return;
    _finPrevisto = DateTime.now().add(_restantePausado!);
    _restantePausado = null;
    _pausado = false;
  }

  void quitar() {
    _eventoId = null;
    _duracionTotal = null;
    _finPrevisto = null;
    _restantePausado = null;
    _pausado = false;
  }
}
