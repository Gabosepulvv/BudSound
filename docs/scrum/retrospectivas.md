# Evidencia de retrospectivas — BudSound

> **Nota de honestidad:** el equipo no llevó actas formales de
> retrospectiva sprint a sprint. Lo que sigue es una reconstrucción
> fiel a partir de los ajustes de rumbo que sí quedaron documentados en
> el repositorio (commits y entradas de `DECISIONES_TECNICAS.md`) — cada
> punto corresponde a una decisión real tomada entre sprints, no a un
> ejercicio inventado. Si alguien del equipo recuerda detalles
> adicionales de una conversación real de retro, agregarlos acá como
> complemento.

## Sprint 1 → Sprint 2

- **Qué funcionó:** tener el backend real conectado desde temprano evitó
  que el equipo siguiera trabajando sobre datos de prueba hardcodeados.
- **Qué no funcionó:** la reproducción de un preview de audio dentro de
  la app (pantalla "Descubrir") quedaba en una zona legal gris respecto a
  los Términos de Servicio de Spotify/YouTube.
- **Ajuste tomado:** se eliminó por completo la reproducción de audio
  dentro de la app y se reemplazó esa pantalla por "Inicio", dejando
  clarísimo que BudSound solo usa metadatos (título, artista, portada),
  nunca el audio.

## Sprint 2 → Sprint 3

- **Qué funcionó:** el cron de limpieza de solicitudes colgadas resolvió
  de raíz el riesgo de dejar pagos retenidos para siempre.
- **Qué no funcionó:** en pruebas en el lugar real de un evento, la app
  no se comportaba bien ante cortes de conexión (varios celulares en la
  misma red/WiFi del local).
- **Ajuste tomado:** se agregó una cola local de solicitudes pendientes
  en el dispositivo, con reintento automático apenas el socket reporta
  reconexión — sin depender de que la persona se dé cuenta y reenvíe a
  mano.

## Sprint 3 → Sprint 4

- **Qué funcionó:** la integración real de MercadoPago (autorizar,
  capturar, cancelar) replicó bien el modelo de "cobro condicionado".
- **Qué no funcionó:** una revisión manual de seguridad encontró varios
  puntos débiles que no se habían priorizado antes (sockets sin exigir
  login, el JWT completo viajando dentro del WebView de pago, contraseña
  de sesión guardada en texto plano en el dispositivo).
- **Ajuste tomado:** sprint completo dedicado a cerrar esos hallazgos
  antes de seguir agregando funcionalidad nueva — se priorizó seguridad
  por sobre features, incluso a costa de atrasar el split de pagos por
  DJ a ese mismo sprint.

## Sprint 4 → Sprint 5

- **Qué funcionó:** el split de pagos por DJ (OAuth) permitió seguir
  el modelo de "BudSound nunca concentra el dinero de terceros".
- **Qué no funcionó:** la navegación compartida entre DJ y Participante
  (ambos con la misma pestaña "Inicio") no aportaba nada distinto para
  el DJ, que ya veía lo mismo en "En vivo" — una pestaña de más.
- **Ajuste tomado:** se separó la navegación por rol: el DJ perdió
  "Inicio" (su contenido se repartió entre "En vivo" y "Perfil"), el
  Participante la conservó tal cual.

## Sprint 5 → Sprint 6

- **Qué funcionó:** el recorrido de bienvenida y el rediseño de marca
  dejaron la app lista visualmente para mostrar a terceros.
- **Qué no funcionó:** al desplegar a Railway para que cualquiera pudiera
  probar la app sin depender de la máquina de nadie del equipo, aparecieron
  problemas que nunca se habían visto en desarrollo local: el envío de
  correo por SMTP directo dejó de funcionar (el hosting bloquea esos
  puertos salientes), y una variable de entorno con un espacio invisible
  rompió la resolución de DNS de forma muy difícil de diagnosticar.
- **Ajuste tomado:** se migró el envío de correo a una API HTTP de
  terceros (Brevo) en vez de SMTP, y se agregó `.trim()` a las variables
  de entorno sensibles para blindar contra ese tipo de error de copiado a
  futuro.

## Limitación conocida: pago real de punta a punta con MercadoPago

El split de pagos por DJ (OAuth de MercadoPago) se implementó y se probó
a fondo contra la API real de MercadoPago, intentando pagos reales de
punta a punta. Esto sacó a la luz una serie de bugs reales del lado de
BudSound que no se notaban en el modo de pago simulado, porque ese modo
nunca llega a llamar a la API real:

- Faltaba `issuer_id` (necesario para tarjetas cuyo rango de numeración
  comparten varios bancos emisores).
- Faltaba `payer.identification` (el RUT del pagador), que MercadoPago
  exige para pagos reales con tarjeta en Chile.
- Faltaba `payer.email`: el token de checkout acotado de 15 minutos (ver
  revisión de seguridad, más abajo) nunca incluyó el correo del
  Participante en su payload, así que se perdía justo en el camino real
  de pago (no en el simulado).
- Se descubrió que MercadoPago no permite captura diferida (autorizar
  ahora, cobrar cuando el DJ acepta — la base del cobro condicionado de
  BudSound) con tarjetas de **débito**, solo con crédito — es una
  restricción de MercadoPago, no un bug; ahora se le avisa claro al
  Participante si intenta pagar con débito.

Los cuatro se corrigieron y se confirmaron con un panel de diagnóstico en
tiempo real construido para esto (ver `GET /api/debug/stream`), que
muestra en vivo el body exacto enviado a MercadoPago y su respuesta.

Dos cosas quedaron fuera del control del equipo, documentadas para la
defensa:

1. **Cuenta real de un DJ:** la cuenta personal de MercadoPago de una DJ
   del equipo no está habilitada por MercadoPago para **recibir** pagos
   todavía — su propio `GET /users/me` devuelve
   `"sell":{"allow":false,"codes":["rejected_by_regulations"]}`, una
   restricción de verificación/regulación que MercadoPago le exige
   directamente a esa cuenta (típicamente formalizar o declarar la
   actividad ante impuestos).
2. **Ambiente de pruebas (sandbox) de MercadoPago:** al intentar simular
   el flujo completo con cuentas y tarjetas de prueba oficiales de
   MercadoPago (para demostrar el cobro condicionado sin dinero real),
   apareció un error distinto y no documentado públicamente por
   MercadoPago (`"Invalid users involved"`) al combinar una cuenta
   vendedora y una compradora de prueba con el split de pagos por DJ
   activo. Se descartaron varias causas (correo del pagador, credenciales
   de prueba vs. reales, qué cuenta vendedora de prueba usar) sin
   encontrar la combinación exacta que MercadoPago espera — quedó
   pendiente al cierre del proyecto.

Como ninguna de las dos depende de corregir código de BudSound, el
equipo decidió explícitamente no bloquearse esperando resolverlas, y
seguir demostrando el flujo completo con el modo de pago simulado para
la presentación (ver Sprint 5 → Sprint 6). La integración técnica del
lado de BudSound está terminada, probada contra la API real, y los bugs
propios que aparecieron ya están corregidos.

## Cierre del proyecto

- **Qué funcionó bien en general:** diseñar cada integración externa
  (pagos, correo, login con Google) para que se activara sola apenas
  hubiera credenciales, sin bloquear el desarrollo mientras no las había.
  Ese patrón se repitió una y otra vez y evitó que una sola integración
  pendiente frenara al resto del equipo.
- **Qué se haría distinto en un próximo proyecto:** llevar actas de
  retrospectiva desde el Sprint 0, en vez de reconstruirlas al final a
  partir del historial de commits — y escribir pruebas automatizadas
  junto con cada funcionalidad, no dejarlas para el final (quedaron
  pendientes al cierre de este proyecto).
