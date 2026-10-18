const QRCode = require('qrcode');
const eventModel = require('../models/event.model');
const asyncHandler = require('../utils/asyncHandler');

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[c]));
}

// Página pública (sin login) pensada para abrirse en una TV o tablet del
// local, no en el celular del DJ — por eso el QR es gigante y no hay
// nada que tocar. El código ya es público por diseño (cualquiera que lo
// vea puede unirse al evento escaneándolo o escribiéndolo a mano, como
// siempre), así que mostrarlo acá no expone nada que el QR impreso o
// mostrado en el celular no exponga igual.
//
// El QR se genera como SVG incrustado directo en el HTML (no una imagen
// externa ni una librería por CDN) para que la página funcione sin
// depender de que el local tenga internet real — solo necesita llegar a
// este backend por la red local, igual que el resto de la app.
const paginaDisplay = asyncHandler(async (req, res) => {
  const code = (req.params.code || '').toUpperCase();
  const event = await eventModel.buscarPorCodigo(code);

  if (!event) {
    return res.status(404).send(paginaError('Evento no encontrado',
      'Revisa que el código esté bien escrito.'));
  }
  if (event.status !== 'ACTIVO') {
    return res.status(410).send(paginaError('Este evento ya cerró',
      'El DJ cerró el evento — pide que genere uno nuevo y vuelve a abrir este link.'));
  }

  const qrSvg = await QRCode.toString(event.code, {
    type: 'svg',
    margin: 1,
    color: { dark: '#070B14', light: '#FFFFFF' },
  });

  res.set('Content-Type', 'text/html; charset=utf-8').send(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(event.nombre)} — BudSound</title>
<style>
  html, body {
    margin: 0;
    height: 100%;
    background: #070B14;
    color: #fff;
    font-family: -apple-system, system-ui, 'Segoe UI', sans-serif;
  }
  body {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2.5vh;
    padding: 4vh 4vw;
    box-sizing: border-box;
  }
  .logo {
    font-size: clamp(16px, 2.2vw, 28px);
    font-weight: 800;
    letter-spacing: 0.08em;
    color: #B4FF39;
    text-transform: uppercase;
  }
  h1 {
    font-size: clamp(22px, 3.5vw, 48px);
    font-weight: 800;
    margin: 0;
    text-align: center;
    max-width: 90vw;
  }
  .qr {
    background: #fff;
    border-radius: clamp(16px, 2vw, 32px);
    padding: clamp(16px, 2.5vw, 40px);
    box-shadow: 0 0 120px rgba(180, 255, 57, 0.25);
  }
  .qr svg {
    width: min(55vh, 60vw);
    height: min(55vh, 60vw);
    display: block;
  }
  .code {
    font-size: clamp(28px, 6vw, 72px);
    font-weight: 800;
    letter-spacing: 0.3em;
    margin-left: 0.3em; /* compensa el letter-spacing al centrar */
  }
  .hint {
    font-size: clamp(14px, 1.8vw, 22px);
    color: #93A2BE;
    text-align: center;
    max-width: 70vw;
  }
</style>
</head>
<body>
  <div class="logo">🎧 BudSound</div>
  <h1>${escapeHtml(event.nombre)}</h1>
  <div class="qr">${qrSvg}</div>
  <div class="code">${escapeHtml(event.code)}</div>
  <div class="hint">Escanea el código o ábrelo en BudSound e ingrésalo a mano para pedir una canción.</div>
</body>
</html>`);
});

function paginaError(titulo, mensaje) {
  return `<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(titulo)}</title></head>
<body style="margin:0;background:#070B14;color:#fff;font-family:-apple-system,system-ui,sans-serif;
  display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px;box-sizing:border-box;text-align:center;">
  <div>
    <h1 style="font-size:28px;margin:0 0 10px;">${escapeHtml(titulo)}</h1>
    <p style="color:#93A2BE;font-size:16px;margin:0;">${escapeHtml(mensaje)}</p>
  </div>
</body></html>`;
}

module.exports = { paginaDisplay };
