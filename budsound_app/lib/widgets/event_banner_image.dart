import 'dart:ui';

import 'package:flutter/material.dart';

/// Banner de imagen de evento — la mayoría de los logos que suben los DJ
/// son cuadrados (flyers/isotipos de eventos de música electrónica), y un
/// `BoxFit.cover` simple sobre un banner ancho y bajo les recorta los
/// costados, perdiendo parte del logo. Acá el mismo recorte se usa solo
/// como fondo (difuminado, para que no se note como un error), y encima
/// va la imagen completa sin recortar (`BoxFit.contain`), centrada.
class EventBannerImage extends StatelessWidget {
  const EventBannerImage({super.key, required this.image, this.height = 140});

  final ImageProvider image;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image(image: image, fit: BoxFit.cover),
          ),
          // Oscurece un poco el fondo difuminado para que el logo (sobre
          // todo uno con fondo claro/transparente) siga resaltando encima.
          Container(color: Colors.black.withValues(alpha: 0.28)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Image(image: image, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
