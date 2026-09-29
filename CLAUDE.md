# BudSound — Proyecto APT / Capstone (Duoc UC)

Este archivo le da contexto a Claude Code cada vez que trabaje en este repo.
Está escrito para que cualquiera del equipo (Danahe, Gabriel, Benjamín) pueda
abrir Claude Code acá y que entienda el proyecto sin tener que re-explicarlo.

## Qué es BudSound

App móvil que digitaliza la interacción entre el público y un DJ en eventos
en vivo (discotecas, bares, eventos masivos). Hoy el público interrumpe
físicamente al DJ para pedir canciones; BudSound reemplaza eso por un canal
digital y ordenado:

1. El DJ crea un evento y genera un código QR.
2. El asistente escanea el QR, busca una canción y envía la solicitud,
   opcionalmente con un monto como incentivo económico.
3. El DJ recibe la solicitud en tiempo real (cola tipo tickets) y decide si
   la acepta o la rechaza. Mantiene el control artístico del set en todo
   momento.

**Es UNA sola aplicación, no dos apps separadas.** Al iniciar sesión la
persona elige/tiene un rol: `PARTICIPANTE` o `DJ`, y la interfaz cambia según
el rol. Ojo con esto en el copy y en la arquitectura — nunca modelar como si
fueran dos productos distintos.

## Equipo y roles

- **Gabriel Sepúlveda** — Product Owner. UI/UX y frontend del DJ.
- **Danahe González** — Scrum Master. Backend, base de datos e integraciones.
- **Benjamín Valenzuela** — Equipo de desarrollo. Pagos y frontend del
  Participante.
- Los tres colaboran en conjunto en pagos y frontend del Participante según
  el plan de trabajo.

## Contexto académico (por qué importa para cómo se construye esto)

Este es el Proyecto APT (Capstone) de la carrera en Duoc UC, evaluado en 3
fases a lo largo de 18 semanas. La Fase 1 (definición del proyecto) ya se
presentó y fue aprobada con estos elementos ya fijos — **no se deben
recontradecir** en el código ni en la documentación que se genere:

- Metodología Scrum, 7 sprints (Sprint 0 al 6), mapeados a fechas reales del
  calendario del ramo.
- El equipo ya identificó y resolvió un riesgo legal antes de programar (ver
  sección "Decisión legal" abajo) — es parte de lo que se evalúa y de lo que
  el equipo debe poder explicar en la defensa.
- Se espera que cada integrante pueda explicar las decisiones técnicas de su
  parte del código, no solo que "funcione".

## Decisión legal / de modelo de negocio (importante, no revertir)

Cobrar por la reproducción de una canción específica entra en conflicto con
los Términos de Servicio de Spotify y YouTube. Por eso:

- El cobro **nunca** se modela como "prioridad de solicitud" ni como algo
  que garantice que la canción se toque. Se modela como una **propina /
  incentivo económico al DJ**, que él evalúa libremente si acepta.
- La búsqueda de canciones usa **iTunes Search API** solo para metadatos
  (título, artista, portada) — nunca para streaming/reproducción. La
  reproducción real sigue siendo desde el equipo del DJ, fuera de la app.
- Esto incluye el preview de 30 s que expone iTunes: **la app nunca lo
  reproduce**, ni en la búsqueda del Participante ni en ninguna otra
  pantalla. Antes existía un reproductor de previews en una pestaña
  "Descubrir" (antes de que existiera el flujo real de eventos) y se
  eliminó por completo (`PreviewPlayer`, `TrackTile`, `ItunesService`,
  `audioplayers`) precisamente por esta regla.

## Stack técnico

- **Frontend:** Flutter — una sola base de código para las vistas de
  Participante y DJ. Vive en `budsound_app/`.
- **Backend:** Node.js + Express, sin ORM (SQL parametrizado con `pg`). Vive
  en `budsound_backend/`.
- **Base de datos:** PostgreSQL (modelo relacional: usuarios, eventos,
  solicitudes, transacciones).
- **Tiempo real:** Socket.io, para la cola de solicitudes en vivo. Una sala
  por evento (`event:<id>`).
- **Pagos:** MercadoPago (Checkout API / Checkout Pro). **Cambiaron desde
  Transbank Webpay** — cualquier código, doc o mockup viejo que mencione
  Transbank está desactualizado, ya no aplica.
  - Aún no tienen credenciales de sandbox de MercadoPago — la integración
    debe quedar con variables de entorno placeholder
    (`MERCADOPAGO_ACCESS_TOKEN`, `MERCADOPAGO_PUBLIC_KEY`) fáciles de
    reemplazar cuando las obtengan.
  - Mientras tanto, `POST /api/requests/:id/payment/simulate-approval`
    simula la aprobación para poder demostrar el flujo completo en el MVP.
- **API musical:** iTunes Search API (gratuita, sin key), consumida solo
  desde el backend (`GET /api/songs/search`).
- **Hosting:** Railway (capa gratuita). Aún no se ha creado el proyecto.
- **QR:** `qr_flutter` para generarlo (DJ), `mobile_scanner` para leerlo
  (Participante), con botón de linterna para lugares con poca luz —
  pinneado en `^4.0.1` sin una razón fuerte para no subir de versión más
  adelante (no es por ningún bug conocido del paquete).

## Arquitectura — regla clave

Ninguna vista (Participante o DJ) accede directamente a la base de datos ni
a APIs externas (MercadoPago, iTunes). **Todo pasa por el backend**, que es
quien valida, autentica y orquesta esas integraciones.

## Navegación de la app

Tres pestañas después de iniciar sesión (`ShellScreen`), iguales para ambos
roles en estructura pero con contenido distinto:

- **Inicio** (`InicioScreen`) — panel de estado rápido, no un catálogo de
  canciones. DJ: acceso directo a su evento activo (o aviso de que no ha
  creado ninguno). Participante: acceso directo al evento que ya escaneó
  (o aviso de que no ha escaneado ningún QR todavía). El código del último
  evento del Participante se guarda localmente en el dispositivo
  (`SessionService.ultimoEventoCode`) y se revalida contra el backend cada
  vez que se abre esta pestaña — si el evento ya cerró, se limpia solo.
- **En vivo** (`LiveScreen`) — donde pasa la acción real: el DJ crea
  eventos y gestiona la cola (`DjEventsScreen` → `DjQueueScreen`); el
  Participante escanea el QR o ingresa el código a mano
  (`ParticipantJoinScreen` → `ParticipantEventScreen`).
- **Perfil** (`ProfileScreen`) — datos de sesión y cerrar sesión.

## Alcance del MVP

**Incluye:** registro/login con rol, creación de evento con QR (DJ) e
ingreso a evento vía QR (Participante), búsqueda de canciones (iTunes Search
API), solicitud de canción con monto opcional ($500–$20.000 CLP), cola de
solicitudes en tiempo real para el DJ con aceptar/rechazar, cobro
condicionado (solo se cobra si el DJ acepta), cierre de evento con
recaudación total y analítica básica.

**Explícitamente fuera de alcance:** reproducción de audio dentro de la app,
perfil público del DJ, ofrecer el servicio a locales/discotecas como
cliente, pago por transferencia bancaria.

## Modelo de negocio

Gratis para el DJ. BudSound cobra una comisión de 5%–10% sobre lo recaudado
en cada evento, aplicada automáticamente en cada transacción aceptada.
Configurable vía `BUDSOUND_COMMISSION_RATE` en el backend (default 8%).

## Riesgos nuevos y mitigaciones (post Fase 1)

Detectados después de la Fase 1, en la sesión de análisis "Nuevos Riesgos".
Igual que con el riesgo legal de Spotify/YouTube, esto se documenta acá
porque el equipo debe poder explicarlo en la defensa, no solo que el código
"funcione". Actualizar esta sección si cambia alguna mitigación.

### 1. Autorización de pago vs. captura (vigencia de 7 días)

Con MercadoPago el pago no se cobra al momento de crear la solicitud: se
autoriza/retiene, y se **captura** después si el DJ acepta, o se **cancela**
si rechaza. La autorización expira sola a los **7 días**. Si una solicitud
queda "colgada" sin respuesta del DJ, hay que capturar o cancelar antes de
ese plazo o el dinero queda en un limbo.

- **Mitigación:** un job (cron) que revise solicitudes pendientes y las
  cancele automáticamente si el evento ya cerró o pasaron varias horas sin
  respuesta del DJ. Nunca depender de que alguien cancele a mano.
- **Captura parcial** (cobrar menos del monto retenido) solo funciona con
  Visa, Mastercard, Amex y Cabal — para el MVP, capturar el monto completo
  o cancelar, sin montos parciales.
- **Estado actual del código:** todavía no implementado (depende de tener
  credenciales reales de MercadoPago para diseñar contra la API real). El
  flujo demo actual (`simulate-approval`) es un placeholder explícito, no
  el flujo final. Cuando lleguen las credenciales, rediseñar
  `mercadopago.service.js` para autorizar en el momento de crear la
  solicitud (no al aceptar) y agregar el cron de limpieza.

### 2. Congestión de red y desconexión en el evento

El problema no es la app en sí, sino que cientos de celulares se conectan a
la misma WiFi/red móvil del lugar al mismo tiempo — algo que no se nota
probando en la casa con dos celulares.

- **Mitigación:** reconexión automática de Socket.io (ya configurada en
  `budsound_app/lib/services/event_socket.dart`) más un indicador visual de
  "sin conexión" en las pantallas de evento. Falta: cola local temporal en
  el celular para no perder una solicitud creada durante un corte de
  conexión de pocos segundos.
- **Antes de la presentación final:** probar con varios dispositivos
  conectados a la vez a la misma red, no solo dos celulares.

### 3. Escaneo de QR con poca luz

Discotecas y lugares con luces en movimiento pueden hacer fallar el
escaneo de la cámara.

- **Mitigaciones:** ingreso manual del código como respaldo (ya existe en
  `ParticipantJoinScreen`); botón de linterna en la pantalla de escaneo;
  recomendar al DJ mostrar el QR en una superficie fija bien iluminada, no
  solo desde el celular en la mano.
- Probar el escaneo en condiciones reales (poca luz, luces en movimiento)
  antes de asumir que funciona igual que en un ambiente iluminado.

### 4. Conectividad de red del lugar del evento

Fuera del control de la app: el lugar puede no tener WiFi o tener mala
señal móvil.

- **Mitigación:** mismo mecanismo de reconexión + cola local del riesgo
  #2, más recomendar al organizador confirmar la conectividad del lugar
  antes de usar BudSound ahí.

### 5. El participante pide devolución del dinero

Una vez que el DJ acepta la solicitud, **no hay devolución** — es como
pedirle a un músico callejero que devuelva la moneda porque no le gustó la
canción.

- **Mitigación:** Términos y Condiciones explícitos que el participante
  acepta (checkbox) antes de pagar, no solo una política verbal. El
  checkbox vive en `ParticipantEventScreen._elegirMonto` y solo es
  obligatorio cuando hay propina (`montoClp > 0`).

### 6. Contracargo (chargeback) — el riesgo más serio

No depende de que BudSound diga que sí o que no: si el participante le dice
a su banco "no reconozco este cargo", MercadoPago abre una disputa y el
monto queda congelado en la cuenta que recibió la plata hasta que se
resuelve. Si el banco falla a favor del cliente, se descuenta y devuelve
aunque el evento ya haya terminado.

- **Mitigación para el MVP:** un registro con timestamp de cada paso —
  solicitud creada, DJ acepta, DJ marca la canción como **reproducida** —
  como evidencia interna para disputar un contracargo vía la API de
  MercadoPago. "Toqué la canción" es mucho más difícil de probar que "envié
  un paquete con seguimiento"; este registro es la única evidencia real
  disponible.
  - Implementado: columna `reproducida_at` en `song_requests`, endpoint
    `PATCH /api/requests/:id/played` (solo DJ, solo sobre solicitudes
    `ACEPTADA`), botón "Marcar como reproducida" en `DjQueueScreen`.
- El tope de $500–$20.000 CLP por solicitud también ayuda: limita cuánto se
  puede perder por cada caso individual si un contracargo se resuelve en
  contra.

### 7. ¿A quién le llega la plata primero? (decisión de arquitectura)

Dos opciones, con el mismo tipo de decisión que el riesgo legal de
Spotify/YouTube — hay que poder explicarla en la defensa:

- **Opción A — Split de pagos (elegida):** el DJ recibe su parte
  automático vía split de pagos de MercadoPago (cuenta propia del DJ),
  menos la comisión de BudSound. Más simple de implementar. El DJ asume el
  riesgo de contracargo en su propia cuenta (su saldo se puede congelar o
  quedar en negativo).
- **Opción B — BudSound concentra el dinero (descartada):** el riesgo lo
  asumiría la plataforma, pero convierte a BudSound en un intermediario de
  pagos con responsabilidad regulatoria que no calza con el alcance de un
  proyecto de título.
- **Por qué A:** mismo argumento que con el riesgo legal — mantener a
  BudSound fuera de la cadena de custodia del dinero tanto como sea
  posible. Cuando existan credenciales de MercadoPago, cada DJ deberá
  conectar su propia cuenta (OAuth de MercadoPago como marketplace) antes
  de poder recibir solicitudes con propina.

## Problemas conocidos del entorno

- **Windows + espacio en la ruta de usuario (RESUELTO en este equipo):** si
  el usuario de Windows tiene un espacio en el nombre
  (ej. `C:\Users\Gabriel Sepulveda\...`), `flutter run`/`flutter build`
  puede fallar con `Building native assets for package:objective_c failed`
  — un bug del hook runner de Dart (no de este proyecto) que se dispara
  cuando algún paquete necesita compilar bindings nativos y la ruta tiene
  espacios. En este repo venía de `audioplayers` (vía
  `path_provider_foundation` → `objective_c`); al eliminar `audioplayers`
  (ver riesgo de previews arriba) el problema desapareció por completo, sin
  ni siquiera necesitar mover carpetas. Si vuelve a aparecer con algún
  paquete nuevo: mover tanto el SDK de Flutter como el proyecto a rutas sin
  espacios (ej. `C:\dev\flutter`, `C:\dev\BudSound`) lo soluciona sin tocar
  la cuenta de Windows; `flutter upgrade` no lo arregla por sí solo
  (probado).
- **`flutter analyze` sí funciona** en este entorno (no depende de los
  hooks nativos); úsalo para verificar el código Dart cuando `flutter run`
  no esté disponible.

## Convenciones (ir completando a medida que el equipo decida)

- Idioma del código (nombres de variables, funciones): inglés.
- Idioma de comentarios y documentación: español.
- Commits: seguir un formato consistente (a definir por el equipo — sugerido
  Conventional Commits).
- Este archivo se debe mantener al día si cambia una decisión de arquitectura
  o de negocio — es la fuente de verdad para cualquiera (o cualquier
  instancia de Claude Code) que entre a este repo por primera vez.
