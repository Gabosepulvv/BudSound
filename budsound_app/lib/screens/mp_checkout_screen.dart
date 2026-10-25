import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api_config.dart';
import '../services/api_client.dart';
import '../services/request_service.dart';
import '../theme/app_colors.dart';

/// WebView con el formulario de tarjeta de MercadoPago (Card Payment Brick,
/// servido por el propio backend en `/pay/checkout`) para tokenizar la
/// tarjeta antes de crear la solicitud — ver CLAUDE.md, riesgo
/// "Autorización de pago vs. captura".
///
/// El `POST /events/:id/requests` (donde se autoriza el pago de verdad) lo
/// hace ESTA pantalla con el cliente HTTP de Dart, no el WebView con
/// `fetch()` — se probó a mano que ese `fetch()` puede quedarse colgado
/// para siempre sin ningún error visible (ni de red, ni de JS), mientras
/// el mismo endpoint responde en ~1s llamado por `package:http` (el mismo
/// cliente que ya usa `_iniciar()` acá abajo para pedir el HTML de la
/// página). La página solo tokeniza la tarjeta y avisa por el canal
/// `BudSoundCheckout`; ver `checkout.controller.js` para el porqué en más
/// detalle.
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
  String? _checkoutToken;
  bool _confirmando = false;

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
      checkoutToken =
          await _requestService.obtenerTokenCheckout(widget.eventId);
      _checkoutToken = checkoutToken;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorInicial = 'No se pudo iniciar el pago. Intenta de nuevo.';
      });
      return;
    }
    if (!mounted) return;

    final checkoutUri = Uri.parse(ApiConfig.checkoutUrl);
    // El POST se hace acá, con el cliente HTTP normal de la app, no
    // dejando que el WebView navegue directo con method: post — el
    // WebView nativo de Android maneja mal un POST con body JSON (falla
    // con "Webpage not available" en vez de mandar la solicitud). Una vez
    // que tenemos el HTML de respuesta, se lo pasamos al WebView con
    // loadHtmlString; baseUrl es necesario para que los recursos relativos
    // que carga esa página (ver checkout.controller.js) resuelvan contra
    // nuestro backend y no contra "about:blank". Ya no se manda el
    // `checkoutToken` acá — la página no vuelve a llamar a nuestra API
    // (ver comentario de la clase), solo esta pantalla lo usa más abajo.
    final String html;
    try {
      final respuesta = await http.post(
        checkoutUri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'eventId': widget.eventId,
          'itunesTrackId': widget.itunesTrackId,
          'titulo': widget.titulo,
          'artista': widget.artista,
          'artworkUrl': widget.artworkUrl,
          'montoClp': widget.montoClp,
          'terminosAceptados': widget.terminosAceptados,
        }),
      );
      if (respuesta.statusCode != 200) {
        throw Exception('status ${respuesta.statusCode}');
      }
      html = respuesta.body;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorInicial = 'No se pudo iniciar el pago. Intenta de nuevo.';
      });
      return;
    }
    if (!mounted) return;

    // Lista blanca de a dónde puede navegar este WebView una vez cargado:
    // nuestro propio backend y el SDK/dominios de MercadoPago que la
    // página misma carga. Cualquier otra navegación (una redirección
    // rara, un intento de phishing) se cancela antes de cargar — antes el
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
        ..loadHtmlString(html, baseUrl: ApiConfig.socketUrl);
    });
  }

  void _onMensajeDePagina(JavaScriptMessage message) {
    if (!mounted) return;
    final texto = message.message;
    _diag('Flutter: mensaje recibido del canal.');

    if (texto.startsWith('error:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(texto.substring('error:'.length)),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Mensaje estructurado del Brick con el token de la tarjeta ya
    // tokenizada (ver checkout.controller.js, onSubmit) — el único caso
    // que no es el string plano "error:...".
    Map<String, dynamic>? datos;
    try {
      datos = jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (datos['tipo'] == 'token') {
      _confirmarPago(
        cardToken: datos['cardToken'] as String,
        paymentMethodId: datos['paymentMethodId'] as String,
        installments: (datos['installments'] as num?)?.toInt(),
        issuerId: datos['issuerId'] as String?,
      );
    }
  }

  /// El POST real a `/events/:id/requests` — hecho acá con el cliente HTTP
  /// de Dart en vez de dentro del WebView, ver el comentario de la clase.
  Future<void> _confirmarPago({
    required String cardToken,
    required String paymentMethodId,
    int? installments,
    String? issuerId,
  }) async {
    if (_confirmando) return;
    _confirmando = true;
    _diag('Flutter: llamando a POST /events/${widget.eventId}/requests…');
    try {
      await _requestService.crear(
        eventId: widget.eventId,
        itunesTrackId: widget.itunesTrackId,
        titulo: widget.titulo,
        artista: widget.artista,
        artworkUrl: widget.artworkUrl,
        montoClp: widget.montoClp,
        terminosAceptados: widget.terminosAceptados,
        cardToken: cardToken,
        paymentMethodId: paymentMethodId,
        installments: installments,
        issuerId: issuerId,
        tokenCheckout: _checkoutToken,
      );
      _diag('Flutter: respuesta OK, solicitud creada.');
      await _avisarResultadoALaPagina(ok: true);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _diag('Flutter: ApiException — ${e.message}');
      await _avisarResultadoALaPagina(ok: false, mensaje: e.message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (error) {
      const mensaje = 'No se pudo conectar con el servidor.';
      _diag('Flutter: error inesperado — $error');
      await _avisarResultadoALaPagina(ok: false, mensaje: mensaje);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text(mensaje), backgroundColor: AppColors.danger),
      );
    } finally {
      _confirmando = false;
    }
  }

  /// Escribe en el panel de diagnóstico de la propia página (ver `diag()`
  /// en checkout.controller.js, expuesta como `window.diag`) — sin esto,
  /// el rastro se corta justo cuando el control pasa de la página al
  /// código de Flutter, que es exactamente la parte que había que poder
  /// ver para encontrar dónde se trababa el flujo real.
  void _diag(String texto) {
    final controller = _controller;
    if (controller == null) return;
    controller
        .runJavaScript('window.diag && window.diag(${jsonEncode(texto)});')
        .catchError((_) {});
  }

  /// Actualiza el texto de estado dentro del WebView (ver
  /// `window.budsoundResultado` en checkout.controller.js) para que la
  /// persona vea "Listo." o el error ahí mismo, en vez de que la página
  /// se quede congelada en "Confirmando con BudSound...".
  Future<void> _avisarResultadoALaPagina({
    required bool ok,
    String? mensaje,
  }) async {
    final controller = _controller;
    if (controller == null) return;
    final mensajeJs = jsonEncode(mensaje ?? '');
    try {
      await controller
          .runJavaScript('window.budsoundResultado($ok, $mensajeJs);');
    } catch (_) {
      // La página pudo haberse descargado ya (ej. si la persona volvió
      // atrás) — no hay nada que avisar en ese caso.
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
                  style: TextStyle(color: AppColors.danger)),
            ),
          if (_cargando)
            Center(
              child: CircularProgressIndicator(color: AppColors.limeGreen),
            ),
        ],
      ),
    );
  }
}
