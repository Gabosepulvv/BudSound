import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/itunes_track.dart';

/// Reproduce previews de 30 s de iTunes (una pista a la vez).
class PreviewPlayer extends ChangeNotifier {
  PreviewPlayer._() {
    _player.onPlayerComplete.listen((_) {
      reproduciendo = false;
      notifyListeners();
    });
    _player.onPlayerStateChanged.listen((state) {
      reproduciendo = state == PlayerState.playing;
      notifyListeners();
    });
  }

  static final PreviewPlayer instance = PreviewPlayer._();

  final AudioPlayer _player = AudioPlayer();
  ItunesTrack? actual;
  bool reproduciendo = false;

  bool esActual(ItunesTrack pista) => actual?.trackId == pista.trackId;

  Future<void> toggle(ItunesTrack pista) async {
    final url = pista.previewUrl;
    if (url == null || url.isEmpty) return;

    if (esActual(pista)) {
      if (reproduciendo) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

    actual = pista;
    reproduciendo = true;
    notifyListeners();
    await _player.play(UrlSource(url));
  }

  Future<void> detener() async {
    await _player.stop();
    actual = null;
    reproduciendo = false;
    notifyListeners();
  }
}
