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
