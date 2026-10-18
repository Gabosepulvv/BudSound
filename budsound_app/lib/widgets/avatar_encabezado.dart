import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/session_service.dart';

/// Foto de perfil del usuario si tiene una (mismo `avatarDataUrl` que edita
/// `ProfileScreen`); si no, el ícono/color de respaldo que le pasen (lima
/// para el DJ, neutro para el Participante) — así el encabezado nunca se ve
/// "roto" para quien todavía no se puso una foto. Compartido entre el
/// saludo del DJ (`DjEventsScreen`) y el del Participante (`InicioScreen`).
class AvatarEncabezado extends StatelessWidget {
  const AvatarEncabezado({
    super.key,
    required this.fondoColor,
    required this.icono,
    required this.iconoColor,
    this.bordeColor,
  });

  final Color fondoColor;
  final IconData icono;
  final Color iconoColor;
  final Color? bordeColor;

  @override
  Widget build(BuildContext context) {
    final avatarDataUrl = SessionService.instance.usuario?.avatarDataUrl;
    ImageProvider? imagen;
    if (avatarDataUrl != null && avatarDataUrl.contains(',')) {
      try {
        imagen = MemoryImage(base64Decode(avatarDataUrl.split(',').last));
      } catch (_) {
        imagen = null;
      }
    }

    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fondoColor,
        borderRadius: BorderRadius.circular(16),
        border: bordeColor != null ? Border.all(color: bordeColor!) : null,
        image: imagen != null
            ? DecorationImage(image: imagen, fit: BoxFit.cover)
            : null,
      ),
      child: imagen == null ? Icon(icono, color: iconoColor, size: 28) : null,
    );
  }
}
