const env = require('../config/env');

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[c]));
}

// Página de checkout que se carga en un WebView solo para tokenizar la
// tarjeta con el "Card Payment Brick" de MercadoPago.js (la tarjeta se
// tokeniza con la Public Key, el número nunca llega al backend de
// BudSound). El POST real a `/api/events/:eventId/requests` (donde se
// dispara `autorizarPago`, ver CLAUDE.md riesgo "Autorización de pago vs.
// captura") lo hace FLUTTER, no esta página — ver el comentario en
// `onSubmit` más abajo para el porqué. El campo `jwt` que llega acá es el
// token de checkout de 15 minutos de `emitirTokenCheckout`
// (`request.controller.js`) / `requireAuthOrCheckoutScope`
// (`auth.middleware.js`); ya no esta página lo usa para nada, pero
// `McpCheckoutScreen` lo guarda y es quien lo usa para autenticar su
// propio POST — sigue siendo un token acotado (15 min, un solo evento), no
// el JWT de sesión completo.
function paginaCheckout(req, res) {
  const {
    eventId,
    itunesTrackId,
    titulo,
    artista,
    artworkUrl,
    montoClp,
    terminosAceptados,
  } = req.body || {};

  if (!eventId || !itunesTrackId || !titulo || !montoClp) {
    return res.status(400).send('Faltan datos para iniciar el pago.');
  }

  const datos = {
    eventId,
    itunesTrackId,
    titulo,
    artista: artista || '',
    artworkUrl: artworkUrl || '',
    montoClp: Number(montoClp),
    terminosAceptados: Boolean(terminosAceptados),
  };

  res.set('Content-Type', 'text/html; charset=utf-8').send(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Pagar propina</title>
<script src="https://sdk.mercadopago.com/js/v2"></script>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; background:#0b0b14; color:#fff; margin:0; padding:16px; }
  h1 { font-size:17px; margin-bottom:4px; }
  p { color:#9aa0b4; margin-top:0; font-size:13px; }
  #estado { margin-top:12px; font-size:14px; color:#9aa0b4; min-height:18px; font-weight:600; }
  #estado.error { color:#ff6b6b; }
  #diag { margin-top:8px; font-size:11px; color:#4a5168; white-space:pre-wrap; word-break:break-all; }
</style>
</head>
<body>
  <h1>Propina de $${datos.montoClp.toLocaleString('es-CL')} CLP</h1>
  <p>${escapeHtml(datos.titulo)}${datos.artista ? ' — ' + escapeHtml(datos.artista) : ''}</p>
  <div id="cardPaymentBrick_container"></div>
  <div id="estado">Cargando formulario de pago…</div>
  <div id="diag"></div>
  <script>
    // El título/artista vienen de resultados de iTunes, no de BudSound —
    // se escapa "</script" para que un título con esa secuencia literal no
    // pueda cortar el bloque de script.
    const datos = ${JSON.stringify(datos).replace(/</g, '\\u003c')};
    const estadoEl = document.getElementById('estado');
    const diagEl = document.getElementById('diag');
    const mp = new MercadoPago(${JSON.stringify(env.mercadopago.publicKey)}, { locale: 'es-CL' });

    function avisarFlutter(mensaje) {
      if (window.BudSoundCheckout) window.BudSoundCheckout.postMessage(mensaje);
    }

    // Red de seguridad de diagnóstico: cualquier error de JS que no haya
    // pasado por nuestro propio try/catch (ej. una excepción dentro del
    // Brick de MercadoPago) igual queda visible EN LA PANTALLA, no solo en
    // el logcat — así una captura de pantalla alcanza para saber qué pasó,
    // sin necesitar conectar el celular a una computadora.
    function diag(texto) {
      console.log('[BudSound]', texto);
      diagEl.textContent = (diagEl.textContent ? diagEl.textContent + '\\n' : '') + texto;
    }
    // Expuesta en window para que Flutter también pueda escribir acá (ver
    // McpCheckoutScreen._diag) — así el panel de diagnóstico muestra una
    // traza continua de los dos lados (JS del WebView + Dart), en vez de
    // perder el rastro justo cuando el control pasa de uno a otro.
    window.diag = diag;
    window.addEventListener('error', (e) => {
      diag('window.onerror: ' + (e.message || e));
    });
    window.addEventListener('unhandledrejection', (e) => {
      diag('unhandledrejection: ' + (e.reason && e.reason.message ? e.reason.message : e.reason));
    });
    diag('Script cargado.');

    // Flutter llama a esto después de hacer el POST real (ver
    // McpCheckoutScreen._onMensajeDePagina) para que la persona vea el
    // resultado acá mismo, en vez de que la pantalla se quede en
    // "Confirmando con BudSound..." sin más explicación.
    window.budsoundResultado = function (ok, mensaje) {
      diag('Resultado de Flutter: ' + (ok ? 'ok' : 'error: ' + mensaje));
      if (ok) {
        estadoEl.textContent = 'Listo.';
        estadoEl.className = '';
      } else {
        estadoEl.textContent = mensaje || 'El pago fue rechazado.';
        estadoEl.className = 'error';
      }
    };

    mp.bricks().create('cardPayment', 'cardPaymentBrick_container', {
      initialization: { amount: datos.montoClp },
      callbacks: {
        // El Brick exige los dos (onReady y onError) para inicializar —
        // sin onReady tira "Callbacks onReady and/or onError are
        // required" y el formulario se queda en blanco para siempre, sin
        // ni siquiera llegar a disparar onError (se vio en el logcat del
        // WebView: el error lo tira cardPayment.js antes de montar nada).
        onReady: () => {
          estadoEl.textContent = '';
          diag('Brick listo.');
        },
        onError: (error) => {
          estadoEl.textContent = 'No se pudo cargar el formulario de pago.';
          estadoEl.className = 'error';
          avisarFlutter('error:No se pudo cargar el formulario de pago.');
          diag('onError del Brick: ' + JSON.stringify(error));
        },
        // No llama a nuestra API desde acá — se probó a mano que el
        // fetch() del WebView hacia nuestro backend puede quedarse colgado
        // para siempre sin ningún error (ni de red, ni del AbortController,
        // ni de JS), mientras el mismo endpoint responde en ~1s llamado
        // por curl o por el cliente HTTP de Dart (package:http, el mismo
        // que ya carga esta página con http.post en
        // mp_checkout_screen.dart). En vez de pelear con eso, el
        // tokenizado de la tarjeta se le pasa a Flutter por el canal
        // BudSoundCheckout y es Flutter quien hace el POST real — ver
        // McpCheckoutScreen._onMensajeDePagina.
        // El Brick llama a onSubmit con los datos de la tarjeta DIRECTO
        // como argumento — no envueltos en { formData }. Desestructurar
        // { formData } acá (como estaba antes) dejaba formData en
        // undefined, y formData.token tiraba
        // "Cannot read properties of undefined (reading 'token')" ANTES
        // de llegar a avisarle nada a Flutter — probablemente la causa
        // real de que esto nunca funcionara, no un problema de red.
        onSubmit: (formData) => {
          diag('onSubmit disparado. Forma del argumento: ' + JSON.stringify(formData));
          estadoEl.textContent = 'Confirmando con BudSound...';
          estadoEl.className = '';
          avisarFlutter(JSON.stringify({
            tipo: 'token',
            cardToken: formData.token,
            paymentMethodId: formData.payment_method_id,
            installments: formData.installments,
          }));
          // Resuelve de una — desde la perspectiva del Brick, "enviar" ya
          // terminó. La confirmación real (ok/error) la manda Flutter de
          // vuelta más abajo, actualizando #estado directo por JS, no a
          // través del Brick (que ya no tiene nada más que validar).
          return Promise.resolve();
        },
      },
    });
  </script>
</body>
</html>`);
}

module.exports = { paginaCheckout };
