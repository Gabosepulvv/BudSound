const env = require('../config/env');

const credencialesListas = () => Boolean(env.email.apiKey && env.email.senderEmail);

const BREVO_API_URL = 'https://api.brevo.com/v3/smtp/email';

// Vía la API HTTP de Brevo (puerto 443, nunca bloqueado) en vez de SMTP
// directo — ver el comentario de `email` en env.js para el porqué.
async function enviarCorreo({ to, subject, html }) {
  const respuesta = await fetch(BREVO_API_URL, {
    method: 'POST',
    headers: {
      'api-key': env.email.apiKey,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { email: env.email.senderEmail, name: env.email.senderName },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  });

  if (!respuesta.ok) {
    const detalle = await respuesta.text().catch(() => '');
    throw new Error(`Brevo respondió ${respuesta.status}: ${detalle}`);
  }
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[c]));
}

// Un solo botón que confirma de inmediato al tocarlo (GET a
// /api/auth/verify-email, ver auth.controller.js) — no hace falta volver a
// abrir la app ni iniciar sesión para que quede confirmado.
async function enviarCorreoVerificacion({ to, nombre, verificationUrl }) {
  const nombreSeguro = escapeHtml(nombre);
  const urlSegura = escapeHtml(verificationUrl);

  await enviarCorreo({
    to,
    subject: 'Confirma tu correo en BudSound',
    html: `<!DOCTYPE html>
<html lang="es">
<body style="margin:0;padding:0;background:#070B14;font-family:-apple-system,system-ui,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#070B14;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" style="max-width:420px;background:#0D1626;border-radius:18px;border:1px solid #1E2C44;padding:32px 28px;">
        <tr><td align="center" style="padding-bottom:18px;">
          <span style="color:#FFFFFF;font-size:22px;font-weight:700;letter-spacing:1px;">budsound</span>
        </td></tr>
        <tr><td style="color:#FFFFFF;font-size:17px;font-weight:700;padding-bottom:8px;">
          Hola, ${nombreSeguro} 🎧
        </td></tr>
        <tr><td style="color:#93A2BE;font-size:14px;line-height:1.5;padding-bottom:24px;">
          Gracias por sumarte a BudSound. Confirma que este correo es tuyo
          para activar tu cuenta y empezar a mover la pista — solo toca el
          botón, no necesitas hacer nada más.
        </td></tr>
        <tr><td align="center" style="padding-bottom:20px;">
          <a href="${urlSegura}" style="display:inline-block;background:#B4FF39;color:#0B1403;font-weight:700;font-size:15px;text-decoration:none;padding:14px 28px;border-radius:14px;">
            Confirmar mi correo
          </a>
        </td></tr>
        <tr><td style="color:#93A2BE;font-size:12px;line-height:1.5;">
          Si el botón no funciona, copia y pega este link en tu navegador:<br/>
          <span style="color:#B4FF39;word-break:break-all;">${urlSegura}</span>
        </td></tr>
        <tr><td style="color:#93A2BE;font-size:12px;padding-top:18px;">
          Este link vence en 24 horas. Si tú no creaste esta cuenta, puedes
          ignorar este correo con tranquilidad.
        </td></tr>
        <tr><td style="color:#4F5A70;font-size:12px;padding-top:22px;">
          — El equipo de BudSound 🎶
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`,
  });
}

// Mismo diseño que `enviarCorreoVerificacion` — un solo botón, nada que
// escribir desde el correo mismo (eso pasa en la página que abre el link,
// ver `paginaRestablecer` en auth.controller.js).
async function enviarCorreoRecuperacion({ to, nombre, resetUrl }) {
  const nombreSeguro = escapeHtml(nombre);
  const urlSegura = escapeHtml(resetUrl);

  await enviarCorreo({
    to,
    subject: 'Recupera tu contraseña de BudSound',
    html: `<!DOCTYPE html>
<html lang="es">
<body style="margin:0;padding:0;background:#070B14;font-family:-apple-system,system-ui,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#070B14;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" style="max-width:420px;background:#0D1626;border-radius:18px;border:1px solid #1E2C44;padding:32px 28px;">
        <tr><td align="center" style="padding-bottom:18px;">
          <span style="color:#FFFFFF;font-size:22px;font-weight:700;letter-spacing:1px;">budsound</span>
        </td></tr>
        <tr><td style="color:#FFFFFF;font-size:17px;font-weight:700;padding-bottom:8px;">
          Hola, ${nombreSeguro} 🎧
        </td></tr>
        <tr><td style="color:#93A2BE;font-size:14px;line-height:1.5;padding-bottom:24px;">
          Recibimos una solicitud para restablecer la contraseña de tu
          cuenta de BudSound. Si fuiste tú, toca el botón para elegir una
          nueva y volver al ritmo.
        </td></tr>
        <tr><td align="center" style="padding-bottom:20px;">
          <a href="${urlSegura}" style="display:inline-block;background:#B4FF39;color:#0B1403;font-weight:700;font-size:15px;text-decoration:none;padding:14px 28px;border-radius:14px;">
            Elegir nueva contraseña
          </a>
        </td></tr>
        <tr><td style="color:#93A2BE;font-size:12px;line-height:1.5;">
          Si el botón no funciona, copia y pega este link en tu navegador:<br/>
          <span style="color:#B4FF39;word-break:break-all;">${urlSegura}</span>
        </td></tr>
        <tr><td style="color:#93A2BE;font-size:12px;padding-top:18px;">
          Este link vence en 1 hora. Si no fuiste tú, puedes ignorar este
          correo con tranquilidad — tu contraseña sigue igual.
        </td></tr>
        <tr><td style="color:#4F5A70;font-size:12px;padding-top:22px;">
          — El equipo de BudSound 🎶
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`,
  });
}

module.exports = { credencialesListas, enviarCorreoVerificacion, enviarCorreoRecuperacion };
