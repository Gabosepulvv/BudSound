import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Detecta el MIME type de una imagen por sus primeros bytes (magic
/// numbers) — usado para armar el data URL (`data:image/...;base64,...`)
/// que tanto la foto de perfil (`ProfileScreen`) como la imagen de un
/// evento (`DjEventsScreen`, `DjQueueScreen`) mandan al backend. Si no
/// matchea PNG ni WEBP, asume JPEG (es lo que entrega la cámara y la
/// mayoría de las galerías).
String detectarMimeImagen(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

String imagenABase64DataUrl(Uint8List bytes) {
  return 'data:${detectarMimeImagen(bytes)};base64,${base64Encode(bytes)}';
}

/// Decodifica un data URL a un `ImageProvider`, o `null` si viene vacío o
/// corrupto — para no arriesgar toda la pantalla por un dato guardado mal.
ImageProvider? decodificarImagenDataUrl(String? dataUrl) {
  if (dataUrl == null || !dataUrl.contains(',')) return null;
  try {
    return MemoryImage(base64Decode(dataUrl.split(',').last));
  } catch (_) {
    return null;
  }
}
