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

// Página de checkout que carga la app (Flutter) en un WebView, nunca un
// navegador público — por eso es seguro pasarle el JWT del Participante
// acá adentro: lo necesita para llamar de vuelta a la API real
// (`/api/events/:eventId/requests`) una vez que tokenizó la tarjeta.
//
// Usa el "Card Payment Brick" de MercadoPago.js: la tarjeta se tokeniza en
// el navegador con la Public Key, el número de tarjeta nunca llega al
// backend de BudSound (ver CLAUDE.md, riesgo "Autorización de pago vs.
// captura" — acá es donde se dispara `autorizarPago`, vía el endpoint de
// crear solicitud).
function paginaCheckout(req, res) {
  const {
    eventId,
    itunesTrackId,
    titulo,
    artista,
    artworkUrl,
    montoClp,
    terminosAceptados,
    jwt,
  } = req.body || {};

  if (!eventId || !itunesTrackId || !titulo || !montoClp || !jwt) {
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
    jwt,
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
  #estado { margin-top:12px; font-size:13px; color:#9aa0b4; min-height:18px; }
  #estado.error { color:#ff6b6b; }
</style>
</head>
<body>
  <h1>Propina de $${datos.montoClp.toLocaleString('es-CL')} CLP</h1>
  <p>${escapeHtml(datos.titulo)}${datos.artista ? ' — ' + escapeHtml(datos.artista) : ''}</p>
  <div id="cardPaymentBrick_container"></div>
  <div id="estado"></div>
  <script>
    // El título/artista vienen de resultados de iTunes, no de BudSound —
    // se escapa "</script" para que un título con esa secuencia literal no
    // pueda cortar el bloque de script.
    const datos = ${JSON.stringify(datos).replace(/</g, '\\u003c')};
    const estadoEl = document.getElementById('estado');
    const mp = new MercadoPago(${JSON.stringify(env.mercadopago.publicKey)}, { locale: 'es-CL' });

    function avisarFlutter(mensaje) {
      if (window.BudSoundCheckout) window.BudSoundCheckout.postMessage(mensaje);
    }

    mp.bricks().create('cardPayment', 'cardPaymentBrick_container', {
      initialization: { amount: datos.montoClp },
      callbacks: {
        onError: (error) => {
          estadoEl.textContent = 'No se pudo cargar el formulario de pago.';
          estadoEl.className = 'error';
          console.error(error);
        },
        onSubmit: ({ formData }) => new Promise((resolve, reject) => {
          estadoEl.textContent = 'Procesando pago...';
          estadoEl.className = '';

          fetch('/api/events/' + encodeURIComponent(datos.eventId) + '/requests', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: 'Bearer ' + datos.jwt,
            },
            body: JSON.stringify({
              itunesTrackId: datos.itunesTrackId,
              titulo: datos.titulo,
              artista: datos.artista,
              artworkUrl: datos.artworkUrl,
              montoClp: datos.montoClp,
              terminosAceptados: datos.terminosAceptados,
              cardToken: formData.token,
              paymentMethodId: formData.payment_method_id,
              installments: formData.installments,
            }),
          })
            .then((r) => r.json().then((body) => ({ ok: r.ok, body })))
            .then(({ ok, body }) => {
              if (!ok) {
                estadoEl.textContent = body.error || 'El pago fue rechazado.';
                estadoEl.className = 'error';
                avisarFlutter('error:' + (body.error || 'El pago fue rechazado.'));
                reject();
                return;
              }
              estadoEl.textContent = 'Listo.';
              avisarFlutter('ok');
              resolve();
            })
            .catch(() => {
              estadoEl.textContent = 'No se pudo conectar con el servidor.';
              estadoEl.className = 'error';
              avisarFlutter('error:No se pudo conectar con el servidor.');
              reject();
            });
        }),
      },
    });
  </script>
</body>
</html>`);
}

module.exports = { paginaCheckout };
