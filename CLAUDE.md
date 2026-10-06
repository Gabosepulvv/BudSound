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
- **Pagos:** MercadoPago (Payments API directa, con Card Payment Brick en
  el frontend — no Checkout Pro, porque Checkout Pro no expone captura
  diferida). **Cambiaron desde Transbank Webpay** — cualquier código, doc
  o mockup viejo que mencione Transbank está desactualizado, ya no aplica.
  - Ya tienen credenciales de sandbox (cuenta de prueba única, Chile) en el
    `.env` local de quien las generó — no están en el repo
    (`.env` está en `.gitignore`). Cada integrante que no tenga las suyas
    propias en su `.env` local sigue viendo el flujo simulado (abajo).
  - `MERCADOPAGO_ACCESS_TOKEN` / `MERCADOPAGO_PUBLIC_KEY` en `.env`
    (`.env.example` trae placeholders). Mientras digan `PLACEHOLDER`,
    `POST /api/requests/:id/payment/simulate-approval` simula la
    aprobación para poder demostrar el flujo sin credenciales reales.
- **API musical:** iTunes Search API (gratuita, sin key), consumida solo
  desde el backend (`GET /api/songs/search`).
- **Login con Google:** implementado en código (`POST /auth/google` en el
  backend, `GoogleSignIn` + selector de rol en `LoginScreen`), pero
  **bloqueado hasta crear el proyecto en Google Cloud Console** — ver
  sección "Login con Google — setup pendiente" más abajo. Mientras no haya
  Client ID configurado, el botón muestra un aviso explícito en vez de
  intentar un flujo que fallaría.
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
- **Estado actual del código:** implementado contra la API real de
  MercadoPago (cuenta de prueba única, sin split de pagos todavía — ver
  Opción A más abajo). `mercadopago.service.js` expone `autorizarPago`
  (captura diferida, `capture: false`), `capturarPago` y `cancelarPago`,
  todo vía `fetch` directo a `/v1/payments` (sin SDK). El participante
  tokeniza la tarjeta en un WebView (`budsound_app/lib/screens/
  mp_checkout_screen.dart`) que carga una página servida por el propio
  backend (`POST /pay/checkout`, `checkout.controller.js`) con el Card
  Payment Brick de MercadoPago.js — el número de tarjeta nunca toca el
  backend de BudSound. Esa página es quien llama a
  `POST /events/:id/requests` con el token ya generado, que autoriza el
  pago y recién ahí crea la solicitud (si MercadoPago rechaza la tarjeta,
  la solicitud no llega a existir). El DJ acepta -> se captura
  (`request.controller.js`); rechaza o el cron la cancela por colgada ->
  se libera. El flujo `simulate-approval` sigue vivo como fallback solo
  para integrantes del equipo que no tengan sus propias credenciales
  reales en su `.env` local (`mercadopagoService.credencialesListas()`
  decide cuál camino tomar).
- **Pendiente:** split de pagos real (Opción A, OAuth marketplace por DJ)
  — sigue sin implementar, documentado como decisión tomada pero no
  construida (ver riesgo "¿A quién le llega la plata primero?" más abajo).
  Con la cuenta única de prueba actual no hay forma de probarlo (haría
  falta una cuenta de MercadoPago de prueba por cada DJ).

### 2. Congestión de red y desconexión en el evento

El problema no es la app en sí, sino que cientos de celulares se conectan a
la misma WiFi/red móvil del lugar al mismo tiempo — algo que no se nota
probando en la casa con dos celulares.

- **Mitigación:** reconexión automática de Socket.io (ya configurada en
  `budsound_app/lib/services/event_socket.dart`) más un indicador visual de
  "sin conexión" en las pantallas de evento. Además, si el Participante
  envía una solicitud justo durante un corte, se guarda localmente
  (`PendingRequestsStore`, `SharedPreferences`) y se reintenta sola apenas
  el socket reporta reconexión — no depende de que la persona se dé cuenta
  y la reenvíe a mano. Solo se encola cuando falla la conexión; si el
  backend responde con un rechazo real (`ApiException`, ej. monto fuera de
  rango) no se reintenta, porque no es un problema de red.
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
  posible.
- **Estado actual del código: implementado.** Cada DJ conecta su propia
  cuenta desde Perfil → "Cobros" → "Conectar MercadoPago" (OAuth, login en
  el navegador del sistema — nunca un WebView propio, ver
  `mercadopago-oauth.service.js` y DECISIONES_TECNICAS.md). Con la cuenta
  conectada, la propina se autoriza directo en la cuenta del DJ con
  `application_fee` = la comisión de BudSound; sin conectar, sigue
  cobrándose en la cuenta central (comportamiento sin split, como antes) —
  mismo patrón resiliente que MercadoPago/Google/SMTP: una capa que se
  activa sola cuando hay credenciales. Ver "Split de pagos por DJ — setup
  pendiente" más abajo.

### 8. Revisión de seguridad del backend/app (2026-10)

Auditoría manual de auth, pagos, sockets y SQL. Dos hallazgos de
prioridad alta ya corregidos; el resto queda anotado para una próxima
pasada (ver detalle y justificación de cada uno en DECISIONES_TECNICAS.md,
entradas 16-19):

- **Corregido — sockets sin autenticación obligatoria:** un socket podía
  conectarse sin JWT y unirse a la sala de cualquier evento (`event:join`)
  sin verificar nada. Ahora el handshake exige un token válido y
  `event:join` confirma que el evento existe (y que el DJ sea dueño antes
  de dejarlo entrar) — ver `sockets/index.js`.
- **Corregido — registro sin verificar el correo:** cualquiera podía
  crear una cuenta con el email de otra persona. Ahora, si hay SMTP
  configurado, el registro manda un correo con un link de un solo click
  que confirma la cuenta (`GET /api/auth/verify-email`) y el login la
  rechaza hasta que se confirme — ver `email.service.js` y "Login con
  Google" abajo (mismo patrón: sin credenciales SMTP, esta capa queda
  apagada y la app funciona como antes).
- **Corregido — JWT completo expuesto en el WebView de pago:** el
  Participante ahora pide un token de checkout de 15 minutos, válido solo
  para crear la solicitud de ESE evento (`POST
  /events/:eventId/checkout-token`) — el resto de la API lo rechaza de
  entrada aunque la firma sea válida. Ver `requireAuthOrCheckoutScope` en
  `auth.middleware.js` y `emitirTokenCheckout` en `request.controller.js`.
- **Corregido — WebView de pago sin restricción de navegación:**
  `mp_checkout_screen.dart` ahora tiene una lista blanca de dominios
  (`onNavigationRequest`) — solo deja navegar al propio backend y a
  dominios de MercadoPago; cualquier otra navegación se cancela.
- **Corregido — `paymentId` del webhook sin validar:** `payment.controller.js`
  exige que sea numérico antes de usarlo para armar la URL que se llama en
  la API de MercadoPago.
- **Corregido — JWT sin cifrar en el celular:** el token de sesión pasó de
  `SharedPreferences` (texto plano) a `flutter_secure_storage` (Keystore en
  Android, Keychain en iOS/macOS) — ver `session_service.dart`. El resto de
  los datos de sesión (nombre, email, rol) siguen en SharedPreferences, no
  son tan sensibles.
- **Corregido — errores 500 con mensaje interno crudo:** `error.middleware.js`
  ahora responde un mensaje genérico en los 500 (y lo loguea completo solo
  en el servidor); los errores controlados (400/401/403/404/409) siguen
  mostrando su mensaje normal, pensado para mostrarse. (Ojo al tocar este
  archivo: debe distinguir por `instanceof ApiError`, no por el número de
  status — un `ApiError(503, ...)` también es intencional y su mensaje es
  seguro de mostrar, aunque 503 sea "quinientos".)

## Split de pagos por DJ — setup pendiente

El código ya está (backend y app — ver riesgo 7 más arriba), pero no
funciona todavía porque hace falta un segundo par de credenciales de
MercadoPago (distinto del Access Token/Public Key que ya se usa para
cobrar propinas):

1. En el panel de MercadoPago, dentro de tu aplicación → **Credenciales** →
   pestaña **OAuth** (no la de "Credenciales de producción/prueba" que ya
   se usó antes). Ahí están el **Client ID** y el **Client Secret** del
   flujo OAuth.
2. En `budsound_backend/.env`:
   - `MERCADOPAGO_CLIENT_ID=...`
   - `MERCADOPAGO_CLIENT_SECRET=...`
3. `PUBLIC_URL` (la misma variable que ya existe para el correo de
   verificación) tiene que apuntar a donde el backend sea alcanzable desde
   afuera — MercadoPago redirige ahí
   (`$PUBLIC_URL/api/dj/mercadopago/callback`) después de que el DJ
   autoriza la conexión. En local no sirve de mucho por la misma razón que
   con el correo (el navegador del DJ no puede llegar a tu `localhost`);
   cobra sentido real con Railway desplegado.
4. Con eso puesto, cualquier DJ puede ir a **Perfil → Cobros → Conectar
   MercadoPago**, lo que abre el login de MercadoPago en el navegador del
   celular (nunca dentro de la app). Al autorizar, MercadoPago lo manda de
   vuelta a una página del backend que confirma la conexión y le pide
   volver a la app.
5. Probar: con el DJ conectado, una propina de prueba en uno de sus
   eventos debería crear el pago en SU cuenta de MercadoPago (revisar en
   su propio panel de "Actividad"), con la comisión de BudSound retenida
   aparte.

## Verificación de correo al registrarse — setup pendiente

Igual que MercadoPago y Google: el código ya está, pero mientras no haya
credenciales SMTP en `budsound_backend/.env`, el registro no exige
verificar el correo (se crea la cuenta y queda logueada de una, como
antes). Para activarlo:

1. Conseguir credenciales SMTP. La opción más simple para probar: Gmail
   con una
   ["contraseña de aplicación"](https://myaccount.google.com/apppasswords)
   (no la contraseña normal de la cuenta — Gmail exige 2FA activado para
   poder generarla).
2. En `budsound_backend/.env`: `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587`,
   `SMTP_USER=<tu correo>`, `SMTP_PASS=<la contraseña de aplicación>`.
3. `PUBLIC_URL` debe apuntar a donde el backend sea alcanzable desde
   afuera (el link del correo se arma con esto) — en local no sirve de
   mucho porque el celular de quien reciba el correo no puede llegar a tu
   `localhost`; esto cobra sentido real recién con Railway desplegado (ver
   RAILWAY_DEPLOY.md), seteando `PUBLIC_URL` al dominio que genera ahí.
4. Con eso puesto, `POST /auth/register` deja de devolver `token` de
   inmediato: devuelve `{ requiereVerificacion: true, email }` y la
   persona debe tocar el link del correo antes de poder iniciar sesión.

## Login con Google — setup pendiente

El código ya está (backend y app), pero no funciona todavía porque hace
falta crear un proyecto en
[Google Cloud Console](https://console.cloud.google.com/) y generar dos
credenciales OAuth. Cualquiera del equipo con acceso a una cuenta de Google
puede hacerlo — no requiere pagar nada (esto es gratis, a diferencia de
MercadoPago):

1. Crear un proyecto nuevo (o usar uno existente) en Google Cloud Console.
2. **Pantalla de consentimiento OAuth:** configurarla en modo "Externo",
   agregar el scope `email` (ya viene por defecto) y, mientras esté en
   modo prueba ("Testing"), agregar como "test user" el correo de Google
   con el que se vaya a probar el login — si no, Google rechaza el login
   para cualquier cuenta que no esté en esa lista.
3. **Credencial OAuth tipo "Android":** nombre de paquete
   `com.example.budsound` (el `applicationId` actual en
   `android/app/build.gradle.kts` — sigue siendo el default de la plantilla
   de Flutter, nadie lo ha cambiado todavía) y el SHA-1 del keystore de
   debug de cada máquina donde se vaya a probar. En esta máquina es:
   `2D:A1:4B:3B:0D:7D:EB:BB:30:C0:1C:5A:F9:EE:A6:AB:BD:90:AC:BF` (se saca
   con `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore
   -alias androiddebugkey -storepass android -keypass android` — cada
   integrante del equipo tiene su propio keystore de debug, así que cada
   uno debe agregar el suyo como credencial Android separada, o nadie más
   que esta máquina va a poder probar el login con Google).
4. **Credencial OAuth tipo "Web":** esta es la que realmente se usa en
   ambos lados — ni el backend ni la app leen la credencial "Android"
   directamente, solo necesitan existir para que Google permita el flujo
   nativo en el celular. El Client ID de la credencial "Web" va en:
   - `budsound_backend/.env` → `GOOGLE_CLIENT_ID=...` (verifica el idToken
     contra esta audiencia, ver `google-auth.service.js`).
   - Al correr la app → `flutter run
     --dart-define=GOOGLE_SERVER_CLIENT_ID=...` (mismo valor — ver
     `lib/core/google_auth_config.dart`). Sin este define, el botón de
     Google muestra "todavía no está configurado" en vez de intentar un
     flujo roto.
5. Probar con el usuario de Google agregado como "test user" en el paso 2.
   La primera vez que alguien nuevo inicia sesión con Google, BudSound
   pregunta el rol (Participante/DJ) antes de crear la cuenta — Google no
   sabe esa parte.

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
- **Compilar para Android falla con `Unable to establish loopback
  connection` (RESUELTO):** el build de Gradle/Kotlin necesita abrir un
  socket local (`localhost`) para hablar consigo mismo, y el Firewall de
  Windows puede bloquear esa conexión para un proceso Java nuevo (recién
  instalado) porque nadie contestó la ventana de "permitir acceso" — sobre
  todo si el build se lanza desde un proceso en segundo plano que no puede
  mostrar esa ventana. Solución: `org.gradle.daemon=false` en
  `android/gradle.properties` (ya aplicado en este repo) evita que el
  daemon de Gradle necesite ese socket; si aparece en otro paquete de la
  cadena de build (Kotlin, AAPT2), correr `flutter run` desde una terminal
  interactiva propia (no en segundo plano) para poder aceptar la ventana
  de Windows Firewall cuando aparezca. Confirmado que vuelve a pasar si se
  reinstala el JDK (Windows ve un `java.exe` "nuevo" aunque la ruta sea la
  misma) — mismo arreglo: terminal interactiva propia, aceptar la ventana.
- **Se necesita JDK 17+ para compilar Android:** el proyecto usa Gradle
  9 / AGP 9 (`android/gradle/wrapper/gradle-wrapper.properties`,
  `android/settings.gradle.kts`), que no corren con Java 8. Si `flutter
  run -d <android>` falla con `JAVA_HOME is set to an invalid directory`
  o simplemente con una versión de Java muy vieja, instalar Eclipse
  Temurin 17 (`winget install EclipseAdoptium.Temurin.17.JDK`) y apuntar
  `JAVA_HOME` ahí.
- **Android SDK sin `cmdline-tools`:** en esta máquina el SDK de Android
  está instalado pero sin `avdmanager`/`sdkmanager` (Android Studio no está
  instalado). Para crear un emulador nuevo hay que armar la carpeta del AVD
  a mano en `%USERPROFILE%\.android\avd\` copiando la estructura de un AVD
  existente y apuntando a una imagen de sistema `x86_64` (no `x86` — las
  versiones recientes de Flutter ya no soportan emuladores de 32 bits).

## Convenciones (ir completando a medida que el equipo decida)

- Idioma del código (nombres de variables, funciones): inglés.
- Idioma de comentarios y documentación: español.
- Commits: seguir un formato consistente (a definir por el equipo — sugerido
  Conventional Commits).
- Este archivo se debe mantener al día si cambia una decisión de arquitectura
  o de negocio — es la fuente de verdad para cualquiera (o cualquier
  instancia de Claude Code) que entre a este repo por primera vez.
