import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api_config.dart';
import '../services/request_service.dart';
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
  final _requestService = RequestService();
  WebViewController? _controller;
  bool _cargando = true;
  String? _errorInicial;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  // El WebView nunca ve el JWT de sesión completo: pide primero un token de
  // checkout acotado (15 min, solo sirve para crear ESTA solicitud) — ver
  // RequestService.obtenerTokenCheckout y CLAUDE.md, revisión de seguridad.
  Future<void> _iniciar() async {
    final String checkoutToken;
    try {
      checkoutToken = await _requestService.obtenerTokenCheckout(widget.eventId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorInicial = 'No se pudo iniciar el pago. Intenta de nuevo.';
      });
      return;
    }
    if (!mounted) return;

    final body = utf8.encode(jsonEncode({
      'eventId': widget.eventId,
      'itunesTrackId': widget.itunesTrackId,
      'titulo': widget.titulo,
      'artista': widget.artista,
      'artworkUrl': widget.artworkUrl,
      'montoClp': widget.montoClp,
      'terminosAceptados': widget.terminosAceptados,
      'jwt': checkoutToken,
    }));

    final checkoutUri = Uri.parse(ApiConfig.checkoutUrl);
    // Lista blanca de a dónde puede navegar este WebView: nuestro propio
    // backend (la página de checkout) y el SDK/dominios de MercadoPago que
    // ella misma carga. Cualquier otra navegación (una redirección rara,
    // un intento de phishing) se cancela antes de cargar — antes el
    // WebView seguía cualquier navegación sin restricción, con JavaScript
    // habilitado y el canal BudSoundCheckout siempre expuesto.
    bool dominioPermitido(String host) {
      return host == checkoutUri.host ||
          host == 'sdk.mercadopago.com' ||
          host.endsWith('.mercadopago.com') ||
          host.endsWith('.mercadolibre.com');
    }

    setState(() {
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
            onNavigationRequest: (request) {
              final host = Uri.tryParse(request.url)?.host ?? '';
              return dominioPermitido(host)
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(
          checkoutUri,
          method: LoadRequestMethod.post,
          headers: const {'Content-Type': 'application/json'},
          body: body,
        );
    });
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
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_errorInicial != null)
            Center(
              child: Text(_errorInicial!,
                  style: const TextStyle(color: AppColors.danger)),
            ),
          if (_cargando)
            const Center(
              child: CircularProgressIndicator(color: AppColors.limeGreen),
            ),
        ],
      ),
    );
  }
}
