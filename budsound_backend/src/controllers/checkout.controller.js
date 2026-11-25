const jwt = require('jsonwebtoken');
const env = require('../config/env');
const mercadopagoService = require('../services/mercadopago.service');
const { asegurarCustomerId } = require('../services/mp-customer.helper');

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[c]));
}

// Página de checkout que se carga en un WebView para tokenizar la tarjeta
// (la tarjeta se tokeniza con la Public Key, el número nunca llega al
// backend de BudSound). Dos caminos posibles, nunca los dos a la vez:
// tarjeta guardada (formulario propio con mp.fields, solo pide el CVV) o
// tarjeta nueva ("Card Payment Brick" de MercadoPago.js) — ver el bloque
// de JS más abajo para el detalle de por qué son dos mecanismos
// distintos. El POST real a `/api/events/:eventId/requests` (donde se
// dispara `autorizarPago`, ver CLAUDE.md riesgo "Autorización de pago vs.
// captura") lo hace FLUTTER, no esta página — ver el comentario en
// `onSubmit` más abajo para el porqué. El campo `checkoutToken` (el mismo
// token de 15 minutos de `emitirTokenCheckout` que ya traía
// `McpCheckoutScreen`, ver DECISIONES_TECNICAS.md) se usa acá para
// resolver/crear el "Customer" de MercadoPago del Participante y listar
// sus tarjetas guardadas. Si el token falta, es inválido, o MercadoPago no
// responde, se sigue sin tarjetas guardadas: cae directo al Brick de
// tarjeta nueva, igual que antes de esta función existir (mismo patrón
// resiliente que el resto de las integraciones opcionales del proyecto).
async function paginaCheckout(req, res) {
  const {
    eventId,
    itunesTrackId,
    titulo,
    artista,
    artworkUrl,
    montoClp,
    terminosAceptados,
    checkoutToken,
  } = req.body || {};

  if (!eventId || !itunesTrackId || !titulo || !montoClp) {
    return res.status(400).send('Faltan datos para iniciar el pago.');
  }

  let customerId = null;
  let payerEmail = null;
  // Tarjetas ya guardadas del Customer — si hay alguna, se le ofrece al
  // Participante un formulario propio de "solo CVV" (ver más abajo, la API
  // mp.fields) ANTES del Card Payment Brick. El Brick (mp.bricks().create
  // con 'cardPayment') nunca mostró tarjetas guardadas: ese feature solo
  // existe en el Payment Brick, distinto al que usa esta página — ver
  // DECISIONES_TECNICAS.md #45, "Card Payment Brick vs. Payment Brick". El
  // camino real para reusar una tarjeta guardada es la API de "Receive
  // payments with saved cards" (mp.fields.createCardToken con el cardId +
  // el CVV reingresado), no Brick.
  let tarjetasGuardadas = [];
  if (checkoutToken && mercadopagoService.credencialesListas()) {
    try {
      const payload = jwt.verify(checkoutToken, env.jwtSecret);
      payerEmail = payload.email || null;
      if (payerEmail) {
        customerId = await asegurarCustomerId(payload.sub, payerEmail);
        const tarjetas = await mercadopagoService.listarTarjetasGuardadas(customerId);
        tarjetasGuardadas = tarjetas.map((t) => ({
          id: t.id,
          ultimosDigitos: t.last_four_digits,
          paymentMethodId: t.payment_method?.id,
          franquicia: t.payment_method?.name,
          issuerId: t.issuer?.id ? String(t.issuer.id) : null,
        }));
      }
    } catch (error) {
      console.error('No se pudo resolver el Customer de MercadoPago (se sigue sin tarjeta guardada):', error.message);
    }
  }

  const datos = {
    eventId,
    itunesTrackId,
    titulo,
    artista: artista || '',
    artworkUrl: artworkUrl || '',
    montoClp: Number(montoClp),
    terminosAceptados: Boolean(terminosAceptados),
    customerId,
    payerEmail,
    tarjetasGuardadas,
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
  #formTarjetaGuardada { display:none; flex-direction:column; gap:10px; }
  #formTarjetaGuardada select { background:#161622; color:#fff; border:1px solid #2a2a3d; border-radius:8px; padding:10px; font-size:14px; }
  #formTarjetaGuardada .cvvCaja { height:20px; display:flex; align-items:center; border:1px solid #2a2a3d; border-radius:8px; padding:8px 10px; background:#161622; }
  #formTarjetaGuardada button { background:#c6ff3d; color:#0b0b14; border:none; border-radius:8px; padding:12px; font-size:15px; font-weight:700; }
  #usarOtraTarjeta { background:none; border:none; color:#9aa0b4; text-decoration:underline; font-size:13px; align-self:flex-start; padding:4px 0; }
</style>
</head>
<body>
  <h1>Propina de $${datos.montoClp.toLocaleString('es-CL')} CLP</h1>
  <p>${escapeHtml(datos.titulo)}${datos.artista ? ' — ' + escapeHtml(datos.artista) : ''}</p>
  <form id="formTarjetaGuardada">
    <select id="selectTarjeta"></select>
    <div class="cvvCaja" id="cvvContainer"></div>
    <button type="submit">Pagar</button>
    <button type="button" id="usarOtraTarjeta">Usar otra tarjeta</button>
  </form>
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

    // Formulario de "pagar con tarjeta guardada": separado del Brick
    // (mp.fields, no mp.bricks) porque el Card Payment Brick no soporta
    // tarjetas guardadas — ver DECISIONES_TECNICAS.md #45. Solo pide el
    // CVV: el resto de los datos de la tarjeta ya los tiene MercadoPago
    // guardados contra customerId.
    const formTarjetaGuardada = document.getElementById('formTarjetaGuardada');
    const cardPaymentBrickContainer = document.getElementById('cardPaymentBrick_container');
    let brickMontado = false;
    let campoCvv = null;

    function montarBrickTarjetaNueva() {
      formTarjetaGuardada.style.display = 'none';
      cardPaymentBrickContainer.style.display = '';
      if (brickMontado) return;
      brickMontado = true;
      // El campo de CVV de "tarjeta guardada" (mp.fields) y el Card
      // Payment Brick usan por debajo la misma infraestructura de Secure
      // Fields de MercadoPago.js — tenerlos montados los dos a la vez
      // (aunque el del CVV quede oculto con display:none) hace que el
      // Brick falle al montarse con "fields_setup_failed_after_3_tries" /
      // "The integration with Secure Fields failed" (probado a mano en la
      // tablet). Hay que desmontar el campo de CVV antes de montar el
      // Brick.
      if (campoCvv) {
        try {
          campoCvv.unmount();
        } catch (error) {
          diag('No se pudo desmontar el campo de CVV: ' + (error && error.message));
        }
        campoCvv = null;
      }
      montarCardPaymentBrick();
    }

    if (datos.tarjetasGuardadas && datos.tarjetasGuardadas.length > 0) {
      diag('Mostrando ' + datos.tarjetasGuardadas.length + ' tarjeta(s) guardada(s).');
      cardPaymentBrickContainer.style.display = 'none';
      formTarjetaGuardada.style.display = 'flex';
      estadoEl.textContent = '';

      const selectTarjeta = document.getElementById('selectTarjeta');
      datos.tarjetasGuardadas.forEach((t) => {
        const opcion = document.createElement('option');
        opcion.value = t.id;
        opcion.textContent = (t.franquicia || 'Tarjeta') + ' terminada en ' + t.ultimosDigitos;
        selectTarjeta.appendChild(opcion);
      });

      campoCvv = mp.fields.create('securityCode', { placeholder: 'CVV' });
      campoCvv.mount('cvvContainer');

      document.getElementById('usarOtraTarjeta').addEventListener('click', montarBrickTarjetaNueva);

      formTarjetaGuardada.addEventListener('submit', async (evento) => {
        evento.preventDefault();
        estadoEl.textContent = 'Confirmando con BudSound...';
        estadoEl.className = '';
        try {
          const tarjeta = datos.tarjetasGuardadas.find((t) => t.id === selectTarjeta.value);
          const token = await mp.fields.createCardToken({ cardId: selectTarjeta.value });
          diag('Token de tarjeta guardada creado.');
          avisarFlutter(JSON.stringify({
            tipo: 'token',
            cardToken: token.id,
            paymentMethodId: tarjeta.paymentMethodId,
            installments: 1,
            issuerId: tarjeta.issuerId,
            customerId: datos.customerId,
          }));
        } catch (error) {
          estadoEl.textContent = 'No se pudo procesar la tarjeta guardada.';
          estadoEl.className = 'error';
          diag('Error creando token de tarjeta guardada: ' + JSON.stringify(error));
        }
      });
    } else {
      montarBrickTarjetaNueva();
    }

    function montarCardPaymentBrick() {
    mp.bricks().create('cardPayment', 'cardPaymentBrick_container', {
      initialization: {
        amount: datos.montoClp,
        // payer.email lo precarga para no pedírselo de nuevo. Ya no se le
        // pasa customerId: el Card Payment Brick no soporta tarjetas
        // guardadas (ver arriba) — este Brick solo se usa para tarjetas
        // nuevas.
        payer: {
          email: datos.payerEmail || undefined,
        },
      },
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
            // Sin esto, MercadoPago puede rechazar el pago con "Params
            // Error" para tarjetas cuyo BIN comparte varios bancos emisores
            // (el Brick ya lo resuelve y lo entrega en formData, pero se
            // estaba descartando acá sin mandarlo a Flutter).
            issuerId: formData.issuer_id,
            // El Brick también pide el RUT del pagador (payer.identification)
            // dentro del mismo formulario — MercadoPago lo exige para pagos
            // reales con tarjeta en Chile (en modo simulado nunca se notó
            // porque no se llegaba a llamar a la API real).
            identificationType: formData.payer?.identification?.type,
            identificationNumber: formData.payer?.identification?.number,
          }));
          // Resuelve de una — desde la perspectiva del Brick, "enviar" ya
          // terminó. La confirmación real (ok/error) la manda Flutter de
          // vuelta más abajo, actualizando #estado directo por JS, no a
          // través del Brick (que ya no tiene nada más que validar).
          return Promise.resolve();
        },
      },
    });
    }
  </script>
</body>
</html>`);
}

module.exports = { paginaCheckout };
