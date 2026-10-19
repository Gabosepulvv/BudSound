# Sprint Backlog — BudSound

Reconstruido a partir del historial real de commits del repositorio (7
sprints, Sprint 0 al 6). Las fechas son las del historial de Git; si la
pauta del ramo exige hacerlas calzar con semanas específicas del
calendario, ajustar solo la numeración de semana, no el contenido.

## Sprint 0 — Definición y arquitectura (hasta 14-09)

**Objetivo:** cerrar el alcance del proyecto, los riesgos (incluido el
riesgo legal de Spotify/YouTube) y la arquitectura base antes de
programar.

- Definición del problema, usuarios y propuesta de valor (Fase 1).
- Decisión de modelar el cobro como "propina", nunca como "prioridad de
  solicitud", para no entrar en conflicto con los Términos de Servicio de
  Spotify/YouTube.
- Elección del stack: Flutter + Node.js/Express + PostgreSQL + Socket.io.
- Estructura inicial del repositorio.

## Sprint 1 — Backend base y conexión real (28-09)

**Objetivo:** tener un backend real funcionando y la app conectada a él,
dejando atrás cualquier dato de prueba hardcodeado.

- Backend desde cero: Express, PostgreSQL (sin ORM), esquema inicial.
- Autenticación, rate limiting y healthcheck.
- Conexión del frontend Flutter al backend real (HU01, HU02).
- Flujo de pago simulado como primera versión, para no bloquear el resto
  del equipo mientras no hubiera credenciales de MercadoPago.

## Sprint 2 — Riesgos, perfil y estabilidad (29-09)

**Objetivo:** cerrar los riesgos detectados después de la Fase 1 y dejar
la base de usuarios/perfil operativa.

- Mitigación de los riesgos nuevos (ver `CLAUDE.md`): reconexión de
  Socket.io, cola local de solicitudes sin conexión, respaldo de ingreso
  manual al evento.
- Se reemplazó la pestaña "Descubrir" (con reproductor de preview de
  audio) por "Inicio", eliminando por completo la reproducción de audio
  dentro de la app — ajuste directo por el riesgo legal (HU de alcance,
  no listada: es una restricción de producto).
- Cron de limpieza de solicitudes colgadas (base de HU14).
- Edición de perfil (nombre, apellido, foto) (parte de HU22).
- Resumen de recaudación persistente tras cerrar un evento (HU10).

## Sprint 3 — Pagos reales y resiliencia de red (02-10)

**Objetivo:** reemplazar el pago simulado por la integración real de
MercadoPago, y endurecer la app ante mala conexión en el lugar del
evento.

- Integración real de MercadoPago: autorización (retención), captura y
  cancelación del pago (HU18).
- Cola local de solicitudes pendientes cuando se corta la conexión, con
  reintento automático al reconectar.

## Sprint 4 — Seguridad, login con Google y split de pagos (06-10)

**Objetivo:** cerrar la auditoría de seguridad del MVP, sumar un segundo
método de login, y resolver a quién le llega la plata primero.

- Auditoría de seguridad completa: sockets exigen JWT válido antes de
  unirse a una sala, JWT de sesión cifrado en el dispositivo
  (`flutter_secure_storage`), token de checkout acotado a 15 minutos para
  el WebView de pago, errores 500 sin filtrar detalles internos.
- Verificación de correo al registrarse (HU04).
- Login con Google Sign-In (HU03).
- Split de pagos por DJ vía OAuth de MercadoPago: cada DJ conecta su
  propia cuenta y cobra ahí, con la comisión de BudSound retenida aparte
  (HU19, HU20).
- Modo daltónico (HU23).
- Rediseño de la pantalla de pedir canción: propina obligatoria, montos a
  medida, búsqueda en vivo (HU11, HU12).
- Fix del Card Payment Brick de MercadoPago (bug de integración, no
  reglas de negocio nuevas).

## Sprint 5 — Rediseño, onboarding y reestructuración por rol (18-10, mañana)

**Objetivo:** pulir la experiencia de cada rol por separado y bajar la
curva de entrada para alguien que recién se registra.

- Reestructuración de la navegación: el DJ pierde la pestaña "Inicio" (su
  contenido se repartió entre "En vivo" y "Perfil"), el Participante la
  conserva.
- Recorrido de bienvenida de 3 pasos, distinto para DJ y Participante,
  con opción de saltarlo (HU24).
- Límite de 7 minutos para que el DJ responda una solicitud, con cuenta
  regresiva visible (HU14).
- Rediseño de marca: paleta rosa/magenta neón.
- Estadísticas y eventos pasados del DJ movidos a Perfil, con historial
  paginado (HU22).

## Sprint 6 — Demo pública, correo confiable y cierre (18-10 tarde a 19-10)

**Objetivo:** dejar una versión distribuible y demostrable sin depender
de la máquina de nadie del equipo ni de dinero real, y cerrar la
documentación para la defensa.

- Despliegue a producción en Railway (backend + PostgreSQL), con dominio
  fijo.
- Modo de pago simulado para el build de demo pública, sin arriesgar
  dinero real (HU21).
- Cambio del envío de correo de SMTP directo a la API HTTP de Brevo (el
  hosting bloqueaba los puertos SMTP salientes).
- Corrección de bugs encontrados en pruebas reales con usuarios:
  recaudación del DJ en $0, pérdida del evento activo al cerrar sesión,
  parpadeo del logo del evento, BPM agregado a la vista previa (HU16).
- Límite anti-spam: 1 solicitud por canción cada 7 minutos por
  participante (HU17).
- Publicación de la pantalla de consentimiento OAuth de Google en modo
  producción.
- README principal, Dockerfile y `docker-compose.yml` para que cualquiera
  levante el proyecto con un solo comando, y documentación de cierre para
  la defensa.
