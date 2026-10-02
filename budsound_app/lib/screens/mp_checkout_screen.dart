import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api_config.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

/// WebView con el formulario de tarjeta de MercadoPago (Card Payment Brick,
/// servido por el propio backend en `/pay/checkout`) para autorizar la
/// propina antes de crear la solicitud — ver CLAUDE.md, riesgo
/// "Autorización de pago vs. captura". La página es quien llama de vuelta a
/// `POST /events/:id/requests` con el token de la tarjeta; esta pantalla
/// solo muestra el WebView y espera el resultado por el canal
/// `BudSoundCheckout`.
class McpCheckoutScreen extends StatefulWidget {
  const McpCheckoutScreen({
    super.key,
    required this.eventId,
    required this.itunesTrackId,
    required this.titulo,
    required this.artista,
    required this.artworkUrl,
    required this.montoClp,
    required this.terminosAceptados,
  });

  final String eventId;
  final int itunesTrackId;
  final String titulo;
  final String artista;
  final String artworkUrl;
  final int montoClp;
  final bool terminosAceptados;

  @override
  State<McpCheckoutScreen> createState() => _McpCheckoutScreenState();
}

class _McpCheckoutScreenState extends State<McpCheckoutScreen> {
  late final WebViewController _controller;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();

    final body = utf8.encode(jsonEncode({
      'eventId': widget.eventId,
      'itunesTrackId': widget.itunesTrackId,
      'titulo': widget.titulo,
      'artista': widget.artista,
      'artworkUrl': widget.artworkUrl,
      'montoClp': widget.montoClp,
      'terminosAceptados': widget.terminosAceptados,
      'jwt': SessionService.instance.jwt ?? '',
    }));

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..addJavaScriptChannel(
        'BudSoundCheckout',
        onMessageReceived: _onMensajeDePagina,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _cargando = false);
          },
        ),
      )
      ..loadRequest(
        Uri.parse(ApiConfig.checkoutUrl),
        method: LoadRequestMethod.post,
        headers: const {'Content-Type': 'application/json'},
        body: body,
      );
  }

  void _onMensajeDePagina(JavaScriptMessage message) {
    if (!mounted) return;
    final texto = message.message;
    if (texto == 'ok') {
      Navigator.of(context).pop(true);
      return;
    }
    if (texto.startsWith('error:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(texto.substring('error:'.length)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pagar propina')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_cargando)
            const Center(
              child: CircularProgressIndicator(color: AppColors.neonBlue),
            ),
        ],
      ),
    );
  }
}
