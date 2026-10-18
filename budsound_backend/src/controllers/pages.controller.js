// Paginas publicas minimas, solo para cumplir el requisito de Google Cloud
// Console (pantalla de consentimiento OAuth: "URL de pagina principal" y
// "URL de politica de privacidad") al publicar la app en modo produccion
// externa. No son parte del flujo de la app (la app movil nunca las abre).
function paginaInicio(req, res) {
  res.set('Content-Type', 'text/html; charset=utf-8').send(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>BudSound</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; background:#0B0A10; color:#fff; margin:0; padding:48px 20px; }
  .wrap { max-width: 480px; margin: 0 auto; text-align: center; }
  h1 { font-size: 24px; margin-bottom: 8px; }
  p { color:#9D9BAE; font-size: 14px; line-height: 1.6; }
  a { color:#FF2D95; }
</style>
</head>
<body>
  <div class="wrap">
    <h1>BudSound</h1>
    <p>
      App para que el público pida canciones a un DJ en eventos en vivo
      mediante un código QR, con propina opcional.
    </p>
    <p>
      Contacto: <a href="mailto:gabrielskt12345@gmail.com">gabrielskt12345@gmail.com</a>
      &middot; <a href="/privacy">Política de privacidad</a>
    </p>
  </div>
</body>
</html>`);
}

function paginaPrivacidad(req, res) {
  res.set('Content-Type', 'text/html; charset=utf-8').send(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Política de privacidad — BudSound</title>
<style>
  body { font-family: -apple-system, system-ui, sans-serif; background:#0B0A10; color:#fff; margin:0; padding:48px 20px; }
  .wrap { max-width: 640px; margin: 0 auto; }
  h1 { font-size: 22px; }
  h2 { font-size: 16px; margin-top: 28px; }
  p, li { color:#9D9BAE; font-size: 14px; line-height: 1.6; }
  a { color:#FF2D95; }
</style>
</head>
<body>
  <div class="wrap">
    <h1>Política de privacidad de BudSound</h1>
    <p>Última actualización: octubre de 2026.</p>

    <h2>Qué información recolectamos</h2>
    <ul>
      <li>Datos de cuenta: nombre, apellido, correo electrónico, fecha de nacimiento y rol (DJ o participante).</li>
      <li>Si inicias sesión con Google: tu nombre, correo y foto de perfil, según lo que Google comparta con tu autorización.</li>
      <li>Datos de uso: eventos creados, solicitudes de canciones enviadas y su estado.</li>
      <li>Si envías una propina: el pago se procesa directamente por Mercado Pago — BudSound no almacena los datos de tu tarjeta.</li>
    </ul>

    <h2>Para qué usamos esta información</h2>
    <p>
      Exclusivamente para operar la app: crear tu cuenta, mostrar tus eventos
      y solicitudes, y procesar propinas a través de Mercado Pago. No vendemos
      ni compartimos tus datos con terceros con fines publicitarios.
    </p>

    <h2>Con quién se comparte</h2>
    <p>
      Con Google (para el inicio de sesión) y Mercado Pago (para procesar
      pagos), únicamente lo necesario para que esas funciones operen.
    </p>

    <h2>Tus derechos</h2>
    <p>
      Puedes pedir la eliminación de tu cuenta y tus datos escribiendo a
      <a href="mailto:gabrielskt12345@gmail.com">gabrielskt12345@gmail.com</a>.
    </p>

    <h2>Contacto</h2>
    <p>
      BudSound es un proyecto de título de Duoc UC.
      Contacto: <a href="mailto:gabrielskt12345@gmail.com">gabrielskt12345@gmail.com</a>.
    </p>
  </div>
</body>
</html>`);
}

module.exports = { paginaInicio, paginaPrivacidad };
