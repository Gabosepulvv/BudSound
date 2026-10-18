# Decisiones técnicas para la defensa — BudSound

Este archivo junta las decisiones técnicas que vale la pena poder explicar
en la defensa del proyecto: cosas que casi nunca se mencionan porque "el
código funciona igual sin ellas", pero que muestran que el equipo pensó en
los problemas reales de producción, no solo en el camino feliz.

Se va actualizando a medida que se agregan cosas de este estilo. Cada
entrada dice: **qué problema resuelve**, **qué se hizo** y **por qué
importa** (el argumento que sirve para la defensa).

---

## 1. Limpieza automática de solicitudes colgadas (cron)

**Problema:** con MercadoPago, un pago no se cobra al tiro — se autoriza y
se retiene, y recién se cobra (captura) si el DJ acepta, o se libera
(cancela) si rechaza. Esa autorización expira sola a los 7 días. Si una
solicitud queda pendiente sin que el DJ la responda — porque se le olvidó,
porque cerró la app, porque terminó el evento — el dinero de esa persona
queda en un limbo indefinidamente.

**Qué se hizo:** un job que corre solo (al arrancar el servidor y después
cada 15 minutos) y cancela automáticamente cualquier solicitud pendiente
cuyo evento ya cerró, o que lleva más de 6 horas sin respuesta del DJ.
Nunca depende de que alguien se acuerde de cancelarla a mano. Además se
diferenció el estado `CANCELADA` (lo hizo el sistema) de `RECHAZADA` (lo
decidió el DJ activamente) — son cosas distintas y conviene poder
distinguirlas si alguna vez hay que revisar qué pasó con una solicitud.

**Por qué importa para la defensa:** es un caso concreto de diseñar para
que el sistema se autocorrija en vez de depender de que un humano se
acuerde de hacer algo. Se puede mostrar en vivo: se probó contra la base de
datos real y canceló solo una solicitud que llevaba días colgada de una
prueba anterior, sin que nadie la tocara.

## 2. Registro de "reproducida" como evidencia ante contracargos

**Problema:** si un participante le dice a su banco "no reconozco este
cargo" o "no recibí el servicio", MercadoPago abre una disputa
(contracargo) y congela el dinero mientras se resuelve — aunque el evento
ya haya terminado. "Toqué la canción" es muy difícil de demostrar sin
evidencia.

**Qué se hizo:** el DJ puede marcar una solicitud aceptada como
"reproducida", lo que guarda un timestamp exacto en la base de datos.
Sumado al timestamp de cuándo se creó la solicitud y cuándo el DJ la
aceptó, queda un registro completo con hora exacta de cada paso — la
evidencia que se presentaría si hay que disputar un contracargo con
MercadoPago.

**Por qué importa para la defensa:** muestra que se pensó en un riesgo de
negocio real (no solo técnico) y se tradujo en una decisión de modelo de
datos concreta, no en una promesa vaga de "ya vamos a ver cuando pase".

## 3. Términos y Condiciones obligatorios antes de pagar una propina

**Problema:** una vez que el DJ acepta una propina, no hay devolución — es
como pedirle a un músico callejero que devuelva la moneda porque no le
gustó la canción. Si eso no queda explícito y aceptado por el participante
antes de pagar, es un problema legal y de reputación.

**Qué se hizo:** el participante tiene que marcar un checkbox aceptando
explícitamente esa condición antes de poder enviar una solicitud con
propina. El backend también lo valida — no es solo una restricción visual
que se pueda saltar.

**Por qué importa para la defensa:** conecta directo con la decisión legal
de la Fase 1 (que el cobro es una propina, no una garantía de
reproducción) — este es el mecanismo concreto que hace cumplir esa regla
en el momento en que el dinero está en juego.

## 4. Resiliencia de red en el lugar del evento

**Problema:** en una discoteca o evento masivo, cientos de celulares
comparten la misma WiFi o red móvil al mismo tiempo — algo que nunca se
nota probando la app en la casa con dos celulares, pero que en el evento
real puede cortar la conexión por unos segundos.

**Qué se hizo:** reconexión automática de la conexión en tiempo real
(Socket.io) con reintentos, más un indicador visual de "sin conexión" en
la pantalla para que quede claro cuándo la app no está sincronizada.

**Por qué importa para la defensa:** es la clase de problema que un equipo
sin experiencia en producción ni siquiera considera hasta que falla en
vivo, frente a todos, el día de la presentación.

## 5. Linterna en el escaneo de QR

**Problema:** las discotecas suelen tener poca luz y luces en movimiento,
lo que puede hacer fallar el escaneo de un código QR con la cámara del
celular.

**Qué se hizo:** botón de linterna en la pantalla de escaneo, más ingreso
manual del código como respaldo si escanear no funciona.

**Por qué importa para la defensa:** ejemplo simple de diseñar pensando en
el ambiente real de uso (una discoteca oscura), no en un ambiente de
oficina bien iluminado.

## 6. Nunca se reproduce audio dentro de la app

**Problema:** la Fase 1 ya definió que iTunes Search API se usa solo para
metadatos (título, artista, portada), nunca para streaming — cobrar por
"prioridad de reproducción" viola los Términos de Servicio de Spotify y
YouTube. Al principio del proyecto existía una pantalla que sí reproducía
un preview de 30 segundos de la canción, heredada de antes de que
existiera el flujo real de eventos.

**Qué se hizo:** se eliminó por completo ese reproductor de audio en toda
la app (no solo se ocultó el botón). No queda ningún camino en el código
donde la app reproduzca sonido.

**Por qué importa para la defensa:** muestra que la decisión legal de la
Fase 1 no se quedó solo en el documento — se auditó el código existente y
se corrigió algo que efectivamente la estaba incumpliendo.

## 7. Manejo de errores de red que no dejan la app "pegada"

**Problema:** si el backend no responde (por la razón que sea — se cayó,
mala conexión, etc.), un error de red mal manejado puede dejar un botón
de carga girando para siempre, sin ningún mensaje, como si la app se
hubiera colgado.

**Qué se hizo:** se encontró y corrigió un caso así en el login/registro:
antes solo se manejaban errores "de servidor" (ej. contraseña incorrecta),
pero no errores de conexión. Ahora cualquier falla de red muestra un
mensaje claro ("No se pudo conectar con el servidor") en vez de dejar la
pantalla congelada.

**Por qué importa para la defensa:** es fácil mostrar un demo que
funciona cuando todo está perfecto; encontrar y arreglar los casos donde
algo falla es lo que distingue una app pensada para gente real.

## 8. Quién recibe la plata primero (split de pagos)

**Problema:** hay que decidir si el dinero llega directo al DJ (con su
propia cuenta de MercadoPago) o si primero pasa por una cuenta de
BudSound y después se le transfiere al DJ.

**Qué se hizo:** se documentó la decisión (Opción A: split de pagos,
cada DJ con su propia cuenta) con el mismo criterio que la decisión legal
de Spotify/YouTube de la Fase 1 — identificar el riesgo, elegir una
opción y explicar por qué. Queda registrado en el CLAUDE.md del proyecto
para cuando se implemente la integración real.

**Por qué importa para la defensa:** demuestra que el equipo entiende que
convertirse en intermediario de pagos trae responsabilidad regulatoria
que no calza con el alcance de un proyecto de título — y que se optó
conscientemente por la opción que mantiene a BudSound fuera de esa
cadena de custodia del dinero.

## 9. Reemplazo de `bcrypt` por `bcryptjs`

**Problema:** la librería original para encriptar contraseñas (`bcrypt`)
necesita compilar código nativo al instalarse, lo que trajo dos
vulnerabilidades (una crítica, una alta) en una dependencia de ese proceso
de compilación, y puede fallar al desplegar en un servidor que no tenga
las herramientas de compilación instaladas.

**Qué se hizo:** se cambió a `bcryptjs`, una versión en JavaScript puro
con la misma función de seguridad, sin necesidad de compilar nada.

**Por qué importa para la defensa:** 0 vulnerabilidades reportadas por
`npm audit` en el backend, y el despliegue en Railway queda más simple y
predecible.

## 10. El resumen de recaudación no se pierde al salir de la pantalla

**Problema:** al cerrar un evento, el DJ veía el resumen (solicitudes
aceptadas, recaudación neta) una sola vez, en un mensaje que aparecía justo
en ese momento. Si salía de esa pantalla — por ejemplo para revisar otra
cosa — no había forma de volver a consultarlo.

**Qué se hizo:** el resumen completo (recaudación bruta, comisión de
BudSound, recaudación neta) queda visible de forma permanente en la propia
pantalla del evento mientras esté cerrado, no solo en el momento de
cerrarlo.

**Por qué importa para la defensa:** un detalle chico, pero es justo el
tipo de cosa que un DJ real necesitaría después del evento — saber cuánto
recaudó no es información de un solo uso.

## 11. Dónde se guarda la foto de perfil (pensando en Railway)

**Problema:** la forma obvia de guardar una foto subida por el usuario es
como archivo en el disco del servidor. Pero Railway, en su capa gratuita,
tiene almacenamiento efímero — cualquier archivo que se guarde así
desaparece en el próximo despliegue o reinicio del servidor.

**Qué se hizo:** la foto de perfil se guarda directo en la fila del
usuario en PostgreSQL, como texto (base64), no como archivo aparte. Pesa
más en la base de datos, pero sobrevive a cualquier redeploy sin depender
de un servicio externo de almacenamiento (que tampoco entraba en el
alcance ni el presupuesto del proyecto).

**Por qué importa para la defensa:** es un ejemplo de una decisión técnica
tomada pensando específicamente en dónde se va a alojar la app (Railway
free tier), no en abstracto — la misma decisión sería distinta si
estuvieran desplegando en un servidor con disco persistente.

## 12. Cola local de solicitudes cuando se corta la conexión

**Problema:** en el evento, cientos de celulares comparten la misma red y
los cortes de un par de segundos son esperables (ver riesgo "Congestión de
red"). La reconexión automática del socket ya evita perder la cola en
tiempo real, pero si el Participante aprieta "Enviar solicitud" justo en
ese corte, el `POST` fallaba y la solicitud se perdía sin que quedara
ningún rastro — la persona tenía que darse cuenta y volver a intentarlo.

**Qué se hizo:** `ParticipantEventScreen` distingue dos tipos de falla al
crear una solicitud: si el backend respondió pero la rechazó
(`ApiException` — ej. monto fuera de rango, términos no aceptados), se
muestra el error y no se reintenta, porque reintentar no cambia el
resultado. Si en cambio no hubo respuesta del backend (corte de conexión),
la solicitud se guarda en el celular (`PendingRequestsStore`, usando
`SharedPreferences`) y aparece en "Mis solicitudes" con un indicador de
"Sin conexión — se enviará sola". Se reintenta automáticamente apenas el
socket del evento reporta que reconectó, y también al deslizar para
refrescar la pantalla.

**Por qué importa para la defensa:** mismo principio que el cron de
limpieza de solicitudes colgadas (ver #1) — diseñar para que el sistema se
autocorrija en vez de depender de que la persona se dé cuenta de que algo
falló y lo reintente a mano, mitigando en el código un riesgo que ya se
había identificado y documentado en la Fase 1.

## 13. Integración real de MercadoPago sin exponer la tarjeta a BudSound

**Problema:** con credenciales de sandbox ya disponibles, había que
reemplazar el placeholder (`simulate-approval`) por el flujo real descrito
en el riesgo "Autorización de pago vs. captura": autorizar (retener) el
pago al crear la solicitud, capturarlo (cobrar) recién cuando el DJ acepta,
o liberarlo si rechaza o se cancela sola. El problema es que eso requiere
tokenizar una tarjeta de crédito — y el número de tarjeta nunca debe pasar
por el backend de BudSound (requisito de PCI, no una elección de diseño).

**Qué se hizo:** la tokenización ocurre en un WebView (`McpCheckoutScreen`
en Flutter) que carga una página HTML servida por el propio backend
(`POST /pay/checkout`) con el "Card Payment Brick" de MercadoPago.js. Esa
página corre con la Public Key, tokeniza la tarjeta en el navegador embebido
y es ella misma quien llama a `POST /events/:id/requests` con el token ya
generado — el backend nunca ve un número de tarjeta, solo un token de un
solo uso. Como el WebView es parte de la app (no un navegador público), la
página recibe el JWT de sesión del Participante para poder hacer esa
llamada autenticada.

Se eligió la Payments API directa (con el Brick) en vez de Checkout Pro
(la opción más simple y habitual) porque Checkout Pro no expone control de
captura diferida — procesa el cobro de inmediato dentro de su propia
página, lo que no permite separar "autorizar" de "cobrar" como exige el
riesgo ya documentado.

**Por qué importa para la defensa:** conecta tres decisiones que ya
estaban documentadas por separado (captura diferida, nunca tocar datos de
tarjeta, cuenta única sin split todavía) en una implementación concreta, y
explica por qué se descartó la opción de integración más simple
(Checkout Pro) a favor de una más compleja pero que sí cumple el diseño
que el equipo ya había decidido.

## 14. Login con Google: un solo endpoint para los dos pasos, sin Firebase

**Problema:** BudSound necesita saber el rol (Participante o DJ) de cada
cuenta — es la decisión que cambia toda la interfaz. Google, en cambio,
solo confirma quién es la persona (nombre, apellido, correo verificado),
nunca ese rol. Había que decidir cómo encajar "preguntar algo que Google no
sabe" dentro de un login que se supone es de un solo toque.

**Qué se hizo:** un único endpoint (`POST /auth/google`) que se llama hasta
dos veces con el mismo `idToken`:

1. Sin `role`: si el correo ya existe en BudSound, loguea directo. Si no
   existe, responde `{ nuevo: true, perfil: {...} }` con lo que Google ya
   confirmó, **sin crear nada todavía**.
2. Con `role` (y `nombreArtistico` si es DJ): recién ahí crea la cuenta.

El backend verifica el `idToken` contra las claves públicas de Google
(`google-auth-library`, JWKS) — nunca contra lo que mande el celular. Las
cuentas creadas por Google quedan con `password_hash = NULL` en la base de
datos (columna que antes era `NOT NULL`), y el login con contraseña
rechaza explícitamente esas cuentas ("esta cuenta se creó con Google") en
vez de intentar comparar contra un hash que no existe.

Se descartó integrar Firebase Auth (la opción más común para esto) porque
hubiera significado una segunda fuente de verdad de usuarios en paralelo a
la tabla `users` de PostgreSQL que ya existe — más complejidad para un
proyecto que ya tiene su propio JWT y su propio modelo de datos, sin
ganar nada a cambio.

**Por qué importa para la defensa:** es un ejemplo de diseñar la
integración con un proveedor externo (Google) alrededor del modelo de
datos propio, no al revés — y de resolver con una sola ruta (dos llamadas)
en vez de inventar un endpoint o una tabla temporal para un "estado a
medio registrar".

## 15. Cambio de paleta a azul marino + verde lima: un solo archivo central y un color de texto nuevo para el contraste

**Problema:** se pidió cambiar la identidad visual de azul neón a "azul
oscuro casi negro con verde lima". Como todas las pantallas ya consumían
los colores a través de una sola clase (`AppColors`, en
`lib/theme/app_colors.dart`) en vez de tener valores hexadecimales sueltos
repartidos por el código, el cambio de marca se redujo a renombrar dos
constantes (`neonBlue` → `limeGreen`, `cobalt` → `limeDark`) y ajustar sus
valores — ninguna pantalla tuvo que tocarse por su lógica, solo por el
nombre del color.

**El detalle que si requirió pensar:** el botón principal
(`NeonGradientButton`) y el selector de rol (`RoleSegmentedControl`)
pintan su texto en blanco fijo sobre el color de acento. Eso funcionaba
con el azul porque era un azul medio-oscuro (buen contraste con blanco),
pero un verde lima vibrante es un color claro — texto blanco encima
prácticamente desaparece. Se agregó `AppColors.onLime` (un verde casi
negro) para esos dos casos puntuales en vez de oscurecer todo el verde lima
general y perder el efecto "neón" en los acentos pequeños (bordes,
íconos, glow) donde sí se ve bien a plena intensidad.

**Por qué importa para la defensa:** mostrar que centralizar la paleta en
un solo archivo (en vez de `Color(0xFF...)` repetidos por todas las
pantallas) convirtió un cambio de identidad visual completo en una edición
de ~30 líneas en un solo lugar — y que un mismo color puede necesitar dos
tratamientos de contraste distintos (texto encima vs. acento sobre fondo
oscuro) según dónde se use.

## 16. Sockets sin autenticación obligatoria: cualquiera podía escuchar la cola de un evento ajeno

**Problema:** `io.use(...)` verificaba el JWT solo si venía uno — si el
socket se conectaba sin token, igual pasaba (`socket.user = null`) en vez
de ser rechazado. Y `event:join` unía al socket a la sala
`event:<id>` que pidiera, sin comprobar que esa sala existiera ni que
quien pedía unirse tuviera algo que ver con ese evento. En la práctica:
alguien que se enterara (o adivinara) el id de un evento ajeno podía
escuchar en tiempo real sus solicitudes de canciones y pagos aprobados,
sin siquiera tener una cuenta en BudSound.

**Qué se hizo:** el handshake ahora exige un JWT válido para conectarse
(`next(new Error(...))` si falta o es inválido — el socket ni siquiera
llega a `connection`). `event:join` pasó a ser `async`: busca el evento
en la base antes de unir, y si quien se une tiene rol DJ, exige que sea el
dueño (`event.dj_id === socket.user.sub`) — mismo criterio que ya se usaba
en las rutas REST de eventos (`event.controller.js`), solo que acá nunca
se había aplicado. Un Participante puede unirse a cualquier evento que
exista (es la intención: el QR es público a propósito), pero ya no a una
sala que ni siquiera corresponde a un evento real.

**Por qué importa para la defensa:** es el ejemplo clásico de que "cada
endpoint REST valida su dueño" no alcanza si hay un segundo canal (acá,
Socket.io) con sus propias reglas de acceso — hay que auditar los dos por
separado, no asumir que una autorización que ya se hizo en un lado cubre
al otro.

## 17. Verificación de correo: confirmar con un clic, sin bloquear el desarrollo sin SMTP

**Problema:** `POST /auth/register` aceptaba cualquier correo sin
confirmar que quien se registraba fuera dueño de esa casilla — alguien
podía crear una cuenta de DJ con el correo real de otra persona del
equipo (o de cualquiera) y usar la app como si fuera ella.

**Qué se hizo:** al registrarse (si hay SMTP configurado — ver
`email.service.js` y `credencialesListas()`, mismo patrón que
MercadoPago/Google) se genera un token aleatorio de 32 bytes, se guarda
**hasheado con SHA-256** en `verificacion_token_hash` (nunca el token en
texto plano — mismo principio que un password hash: si la base se filtra,
nadie arma el link de otra persona con lo que queda ahí) y se manda un
correo con un botón a `GET /api/auth/verify-email?token=...`. Ese
endpoint es público a propósito (quien lo abre es un navegador llegando
desde el correo, no la app) y hace la verificación y limpieza del token en
una sola query atómica (`UPDATE ... WHERE token_hash = $1 AND expira >
now() RETURNING ...`), así que un link reusado o vencido simplemente no
encuentra fila y falla con un mensaje claro. `iniciarSesion` rechaza con
403 a quien todavía no haya confirmado. Las cuentas creadas con Google
quedan verificadas de inmediato (Google ya confirmó `email_verified` en el
id token — pedir que lo reconfirmen hubiera sido redundante).

**Por qué el registro NO queda bloqueado sin credenciales SMTP:** mismo
criterio que ya existía para MercadoPago y Google en este proyecto — una
capa de seguridad extra no debería impedirle a nadie del equipo levantar
el proyecto en su máquina solo porque no configuró un proveedor de correo.
Sin SMTP, `email_verificado` se marca `true` al crear la cuenta y todo
sigue funcionando exactamente como antes de este cambio.

**Por qué importa para la defensa:** token de un solo uso, hasheado, con
vencimiento, y una verificación que es una sola operación atómica en vez
de "buscar y después actualizar" (que tendría una ventana de carrera) — es
el mismo nivel de cuidado que ya se usa para las contraseñas (bcrypt) y
para los pagos (autorizar/capturar), aplicado a un tercer flujo sensible.

## 18. Token de checkout acotado: el WebView de pago deja de ver el JWT completo

**Problema:** `McpCheckoutScreen` abre un WebView que carga una página
servida por el propio backend (`POST /pay/checkout`) para tokenizar la
tarjeta con el SDK de MercadoPago. Esa página necesita un JWT para poder
llamar de vuelta a `POST /events/:eventId/requests` una vez tokenizada la
tarjeta — y hasta ahora se le pasaba el JWT de sesión completo (7 días,
acceso total a la cuenta), dentro de una página que **también** carga
JavaScript de un tercero (el SDK de MercadoPago). Si ese SDK, un CDN
comprometido, o cualquier bug futuro en esa página llegaran a exponer ese
token, quien lo consiguiera podía actuar como esa persona en toda la app,
no solo pagar esa propina.

**Qué se hizo:** un nuevo endpoint, `POST
/events/:eventId/checkout-token` (con el JWT normal), devuelve un token
distinto — mismo formato JWT, pero con `scope: 'checkout'`, `eventId` y 15
minutos de vencimiento. `requireAuth` (el middleware que protege el resto
de la API) ahora rechaza cualquier token que traiga `scope`, aunque la
firma sea válida — así, aunque ese token se filtrara desde el WebView, no
sirve para nada fuera de crear la solicitud de ese evento puntual. Solo la
ruta de creación de solicitudes usa un middleware nuevo
(`requireAuthOrCheckoutScope`) que acepta ambos: el JWT normal (como antes,
para las solicitudes sin propina que la app crea directo) o un token de
checkout que coincida con el `eventId` de la URL.

De paso, el WebView ganó una lista blanca de navegación
(`onNavigationRequest`): solo puede navegar al propio backend y a dominios
de `mercadopago.com`/`mercadolibre.com`. Antes seguía cualquier
redirección sin restricción, con JavaScript habilitado y el canal
`BudSoundCheckout` siempre expuesto.

También se endureció el webhook de MercadoPago: ahora exige que el
`paymentId` recibido sea numérico antes de usarlo para armar la URL que se
llama en la API de MercadoPago (`/v1/payments/${paymentId}`) — sin eso, un
id con formato raro podía hacer que esa llamada golpeara una ruta distinta
de esa API usando nuestro access token.

**Por qué importa para la defensa:** principio de menor privilegio
aplicado a un canal que combina dos cosas riesgosas a la vez (un token de
sesión y JavaScript de un tercero) — en vez de confiar en que "nada va a
salir mal", se diseñó para que, si algo sale mal ahí, el daño quede acotado
a una operación de 15 minutos sobre un evento específico, no a la cuenta
completa.

## 19. JWT cifrado en el celular (flutter_secure_storage)

**Problema:** el JWT de sesión vivía en `SharedPreferences`, que en
Android es un archivo XML en texto plano dentro del almacenamiento privado
de la app — legible con acceso físico al celular o por ADB (`adb shell run-as
com.example.budsound cat ...`), sin necesitar la contraseña de la cuenta.

**Qué se hizo:** el JWT se movió a `flutter_secure_storage` (Keystore de
Android, Keychain en iOS/macOS) — el resto de los datos de sesión (email,
nombre, rol, el perfil) se quedó en SharedPreferences porque no son tan
sensibles y son más simples de leer de forma sincrónica. Se agregó una
migración de una sola vez (`_leerJwtConMigracion`): si alguien ya tenía
sesión iniciada con la versión vieja de la app, su JWT se mueve solo la
primera vez que abre esta versión, sin tener que volver a loguearse.

**Nota de este equipo en particular:** este paquete trae de vuelta
`path_provider_foundation`/`objective_c` como dependencia transitiva — la
misma cadena que causó el bug de "Building native assets... failed" en
Windows cuando la ruta del usuario tiene espacios (ver "Problemas
conocidos del entorno"). Se probó un build de Android completo después de
agregarlo y no se repitió (el proyecto y el SDK de Flutter ya viven en
`C:\dev`, sin espacios) — pero si alguien del equipo corre esto desde una
ruta con espacios, es el primer sospechoso si vuelve a aparecer ese error.

**Por qué importa para la defensa:** es la diferencia entre "el token está
guardado" y "el token está guardado de forma que alguien con el celular en
la mano, pero sin la contraseña, no puede simplemente leerlo".

## 20. Split de pagos por DJ: OAuth en el navegador del sistema, nunca en un WebView propio

**Problema:** hasta ahora, todas las propinas de todos los eventos se
cobraban en una sola cuenta de MercadoPago (la de BudSound) — la decisión
de arquitectura ya tomada en la Fase 1 ("¿A quién le llega la plata
primero?", Opción A) decía que cada DJ debía recibir su parte directo en
su propia cuenta, pero eso no estaba implementado.

**Qué se hizo:** MercadoPago ofrece OAuth como "marketplace": un DJ
autoriza a BudSound a operar pagos a nombre de su cuenta, y cada pago lleva
un `application_fee` que MercadoPago retiene aparte para la plataforma —
así el dinero nunca pasa por una cuenta de BudSound, va directo del
Participante al DJ, menos la comisión. El flujo:

1. El DJ toca "Conectar MercadoPago" en su Perfil. El backend arma la URL
   de autorización con un `state` firmado (JWT de 10 minutos, con
   `purpose: 'mp-connect'` para que no se pueda reusar un JWT de sesión
   cualquiera como si fuera un state — mismo cuidado que con el token de
   checkout, entrada 18).
2. **Esa URL se abre en el navegador del sistema (`url_launcher`,
   `LaunchMode.externalApplication`), nunca en un WebView controlado por la
   app.** El DJ inicia sesión con su contraseña de MercadoPago ahí — pedirle
   su contraseña a una pantalla que nosotros controlamos sería exactamente
   el antipatrón que se evitó en la entrada 18 (JWT en un WebView con JS de
   terceros), aplicado a algo todavía más sensible: la contraseña real de
   su cuenta de banco/pago.
3. MercadoPago redirige a `GET /api/dj/mercadopago/callback` (una ruta del
   backend, pública — la llama el navegador, no la app) con un `code`. El
   backend lo cambia por `access_token`/`refresh_token` y los guarda en la
   fila del DJ. Esa página responde un HTML simple ("vuelve a la app"); no
   hay deep link de vuelta a la app todavía, así que el DJ vuelve a mano y
   la pantalla de Perfil tiene un botón de refrescar para confirmar la
   conexión.
4. Al crear una solicitud con propina, el backend busca si el DJ del
   evento tiene una conexión guardada (`obtenerAccessTokenVigente`, que de
   paso renueva el token solo si está por vencer) — si la tiene, autoriza
   el pago con SU token y `application_fee`; si no, cae al comportamiento
   de siempre (cuenta central de BudSound). Capturar/cancelar más tarde
   usan el mismo criterio, porque MercadoPago exige operar un pago desde la
   misma cuenta que lo autorizó.

**Por qué no se guardó "con qué cuenta se autorizó" en la transacción:**
se decidió re-consultar la conexión actual del DJ en vez de guardar un
snapshot — es una fila menos que mantener sincronizada, y el caso donde un
DJ desconecta su cuenta entre que autoriza una propina y la acepta es raro
y ya falla de forma segura (MercadoPago rechaza operar el pago con una
cuenta que no lo autorizó, en vez de cobrarlo silenciosamente en el lugar
equivocado).

**Por qué importa para la defensa:** mismo flujo de pago (autorizar →
capturar/cancelar) que ya existía, extendido para soportar dos "cuentas
destino" sin bifurcar el código en dos caminos separados — y una decisión
de seguridad consistente con la entrada 18: cuando hay credenciales reales
de por medio (sesión, contraseña de un banco), el lugar más seguro para
ingresarlas es fuera del control de la propia app.

---

## 21. Modo daltónico: colores como getters, no `const` — y por qué `ShellScreen` necesita su propio listener

**Problema:** se pidió un modo accesible para daltonismo. La app usa verde
lima como color de marca y rojo para errores — justo la combinación que
menos distingue alguien con protanopia/deuteranopia (daltonismo rojo-verde,
el tipo más común con diferencia sobre los otros). La solución de diseño
era clara (reemplazar esos dos colores por azul/naranja, que sí se
distinguen bien entre sí independiente del tipo de daltonismo), pero
activarlo en tiempo real resultó más enredado de lo esperado.

**Qué se intentó primero y se descartó:** aplicar un filtro de color
global (`ColorFiltered`) sobre toda la app. Es la técnica que usan los
sistemas operativos para "corrección de color", pero tiñe absolutamente
todo por igual — el fondo azul marino, las fotos de perfil, el arte de las
canciones de iTunes — no solo los dos colores que realmente necesitan
cambiar. Se descartó por una solución más quirúrgica: cambiar solo
`AppColors.limeGreen`, `limeDark` y `danger`.

**El problema técnico:** esos tres pasaron de `static const Color` a
`static Color get` (leen `ColorblindModeService.instance.enabled`). Un
getter no es una constante de compilación, así que **cualquier** `const
TextStyle(color: AppColors.danger)` (o `BorderSide`, `Icon`, `SnackBar`,
etc.) en toda la app dejaba de compilar — fueron ~45 sitios en 12 archivos.
No había forma de evitar tocar cada uno: se sacó la palabra `const` de cada
constructor que dejó de ser una constante válida (nunca de sus hijos no
relacionados), verificando con `flutter analyze` hasta dejar el proyecto en
cero errores.

**El segundo problema, más sutil:** con los colores ya dinámicos, tocar el
switch en Perfil no se reflejaba en las otras pestañas (Inicio, En vivo)
hasta salir y volver a entrar. Causa: `ShellScreen` mantiene las tres
pestañas vivas con un `IndexedStack`, y dos de ellas se instanciaban como
`const LiveScreen()` / `const ProfileScreen()` — una instancia `const` es
literalmente el mismo objeto en cada rebuild, así que Flutter nunca vuelve
a construirla aunque el padre sí se reconstruya (es la misma optimización
que normalmente ayuda al rendimiento, acá jugaba en contra). La solución:
sacarles el `const` a esos dos widgets Y envolver el `build()` de
`ShellScreen` en su propio `ListenableBuilder` sobre el mismo servicio —
escuchar el cambio "cerca" de donde vive el `IndexedStack`, en vez de
confiar en que se propague solo desde `MaterialApp` varios niveles más
arriba (que no era seguro que sucediera, por el mismo motivo del `const`).

**Por qué importa para la defensa:** un cambio de "accesibilidad" que
suena a una sola línea (cambiar dos colores) terminó siendo una lección
concreta sobre cómo interactúan `const` y el árbol de widgets de Flutter —
y por qué "reconstruir el padre" no garantiza que el hijo se reconstruya,
dos cosas fáciles de pasar por alto hasta que un toggle en tiempo real deja
de funcionar silenciosamente en una pantalla que no es la que se está
mirando.

---

## 22. El WebView de pago falla con POST nativo: se hace el POST aparte y se carga el HTML ya resuelto

**Problema:** al probar el pago real en el emulador, `McpCheckoutScreen`
mostraba la pantalla de error nativa de Android ("Webpage not available")
en vez del formulario de MercadoPago. La pantalla usaba
`WebViewController.loadRequest(uri, method: post, body: ...)` para que el
WebView mandara el POST directo — es un patrón con fallas conocidas en la
implementación Android de `webview_flutter` (el `postUrl` nativo maneja
mal un body JSON con headers custom).

**Qué se hizo:** el POST a `/pay/checkout` se hace con el cliente HTTP
normal de la app (`package:http`, el mismo que usa el resto de la app y
nunca tuvo este problema), y recién con el HTML de la respuesta en mano se
lo pasa al WebView con `loadHtmlString(html, baseUrl: ...)`. El `baseUrl`
es necesario porque esa página hace `fetch('/api/events/...')` con una
ruta relativa (ver `checkout.controller.js`) — sin `baseUrl` esa ruta
relativa resolvería contra `about:blank` en vez del backend.

**Por qué importa para la defensa:** es un ejemplo de no asumir que toda
la superficie de una librería (acá, `loadRequest` con POST) está igual de
probada — la ruta GET es la que casi todo el mundo usa y la que mejor
funciona; mover la parte riesgosa (el POST) a una librería HTTP genérica
en vez de dejársela al WebView nativo es más confiable y, de paso, más
fácil de debuggear (los errores de red quedan en el log de Dart, no en una
pantalla de error nativa sin detalle).

---

## 23. El Card Payment Brick de MercadoPago exige `onReady`: encontrado leyendo logcat del WebView, no adivinando

**Problema:** después del fix de la entrada 22, el POST ya llegaba bien al
backend y el WebView cargaba la página — pero el formulario de tarjeta se
quedaba en un recuadro blanco vacío para siempre, sin ningún error visible
en la pantalla.

**Cómo se encontró:** en vez de adivinar, se leyó directo el log nativo
del WebView con `adb logcat | grep chromium` mientras se reproducía el
error en el emulador. Ahí apareció la causa exacta:

```
[INFO:CONSOLE] "Uncaught (in promise) Error: [undefined error]
Callbacks onReady and/or onError are required",
source: .../op-cho-bricks/.../cardPayment.js
```

El Brick de MercadoPago exige los callbacks `onReady` **y** `onError` para
inicializar — `checkout.controller.js` solo tenía `onError` y `onSubmit`.
Sin `onReady`, el Brick ni siquiera llega a intentar dibujarse.

**Qué se hizo:** se agregó `onReady` (limpia el texto de "Cargando…") y de
paso `onError` ahora también avisa a Flutter por el canal
`BudSoundCheckout` (antes solo cambiaba texto dentro del WebView, invisible
si el contenedor del Brick tapaba ese texto).

**Por qué importa para la defensa:** `adb logcat` (o el inspector remoto de
`chrome://inspect` para WebViews) es la herramienta correcta para depurar
"una página web que corre dentro de una app" — los errores de JS ahí NO
aparecen en la consola de Flutter ni en ningún lado dentro del propio
código Dart, porque ocurren en un proceso de renderizado aparte (el
WebView). Sin mirar ese log, esto se habría intentado arreglar a ciegas.

## 24. Propina obligatoria y en múltiplos de $50: pivote post-MVP, validado en los tres niveles

**Problema:** la Fase 1 definió la propina como opcional (monto $0 también
válido). El equipo decidió revertir esa decisión: pedir una canción ahora
siempre requiere propina. Además, para que el monto se pueda pagar en
efectivo sin andar buscando vueltas raras, tiene que ser múltiplo de $50
(termina en 0, decena en 0 o 5 — ej. 600, 650, 700).

**Qué se hizo:** la regla se aplica en los tres lugares donde podría
saltarse, no solo en la app:

1. **UI** (`participant_event_screen.dart`): el diálogo de monto ya no
   tiene la alternativa "Sin propina" — solo hay montos predefinidos más
   un campo "Otro monto" que valida en vivo (múltiplo de 50, entre $500 y
   $20.000) antes de dejar enviar.
2. **Backend** (`request.controller.js`): la misma validación exacta,
   porque nada obliga a que la solicitud venga de la app — alguien podría
   pegarle directo a la API.
3. **Base de datos** (`schema.sql`, tabla `song_requests`): un `CHECK
   (monto_clp BETWEEN 500 AND 20000 AND monto_clp % 50 = 0)` — la última
   barrera si algún bug futuro en el backend se saltara su propia
   validación.

**Por qué importa para la defensa:** es el mismo principio que ya se
aplicaba a la comisión y al monto máximo/mínimo (nunca confiar solo en lo
que valida el cliente) — acá se ve especialmente claro porque la regla
("múltiplo de 50") es nueva y hubo que agregarla a los tres niveles a la
vez para que fuera real, no solo cosmética en la pantalla.

## 25. Canciones "populares" por defecto: el feed RSS de iTunes, no la Search API

**Problema:** la búsqueda de canciones arrancaba vacía — "Busca una
canción para pedirla" — hasta que la persona escribía algo. Se pidió que
ya aparecieran canciones de entrada.

**Qué se hizo:** iTunes tiene dos APIs públicas distintas: la Search API
que ya se usaba (`itunes.apple.com/search`, necesita un término) y un feed
RSS de charts reales (`itunes.apple.com/cl/rss/topsongs/limit=20/json`,
sin término, sin key) con el Top 20 actual de Chile. Se agregó
`itunesService.topCanciones()` que consume ese segundo feed y lo mapea al
mismo formato que ya devolvía la búsqueda normal (`GET /api/songs/top`),
para que el frontend no tenga que distinguir entre "resultado de búsqueda"
y "popular" más que en la etiqueta que muestra arriba de la lista.

De paso, la búsqueda por texto pasó de "hay que tocar la lupa o Enter" a
buscar sola 400ms después de que la persona deja de escribir
(`Timer`+debounce en `participant_event_screen.dart`) — si borra todo el
texto, vuelve a mostrar las populares en vez de quedar en blanco.

**Por qué importa para la defensa:** evitar la tentación de "hardcodear
una lista de canciones populares a mano" — había una fuente real y
gratuita (el chart oficial de iTunes) que resuelve el mismo problema con
datos de verdad y sin mantenimiento.

---

## 26. BPM de la canción pedida, visible para el DJ: Deezer, no iTunes

**Problema:** se pidió que el DJ pudiera ver el BPM de cada canción que le
piden, para poder mezclarla sin tener que buscarlo a mano en otra app.
Ni iTunes (Search API ni el feed RSS) expone BPM en ningún endpoint
público.

**Qué se hizo:** la API pública de Deezer sí tiene BPM, pero solo en el
detalle de una canción (`GET /track/:id`), no en los resultados de
`/search` — hace falta encadenar dos requests: buscar por texto
(`"$artista $titulo"`) para obtener el `id` de Deezer, y después pedir el
detalle de ese `id` para leer `bpm`. Se agregó `deezer.service.js` con
`buscarBpm({titulo, artista})`, y se llama una sola vez al crear la
solicitud (`request.controller.js` → `crear`), guardando el resultado en
la nueva columna `song_requests.bpm` — así la cola del DJ no repite la
consulta externa cada vez que se refresca.

Dos detalles no obvios, encontrados probando contra la API real:
- La sintaxis de filtros de Deezer (`q=track:"X" artist:"Y"` combinados)
  devuelve 0 resultados en la práctica, aunque cada filtro funcione por
  separado. Una búsqueda de texto simple (`q="$artista $titulo"`) sí
  funciona, y Deezer ordena por relevancia/popularidad, así que el primer
  resultado ya suele ser la versión original y no un remix o cover.
- Deezer devuelve `bpm: 0` (no `null`) cuando tiene la canción pero no la
  analizó — se trata como "desconocido" (`bpm > 0 ? bpm : null`).

Es "mejor esfuerzo" de punta a punta: si Deezer no tiene la canción, no la
analizó, o no responde a tiempo (`AbortSignal.timeout(3000)`), se guarda
`null` y la cola del DJ simplemente no muestra el dato — nunca bloquea ni
retrasa de forma relevante pedir una canción.

**Por qué importa para la defensa:** es el mismo patrón que el feed RSS de
iTunes (decisión 25) — usar una fuente pública gratuita en vez de
mantener una base de datos de BPM a mano — pero con una capa extra de
tolerancia a fallos porque acá el dato es "nice to have", no el flujo
principal (pedir la canción nunca debe depender de que un tercero
responda).

---

## 27. "Procesando pago..." colgado para siempre: cleartext bloqueado solo dentro del WebView

**Problema:** en el emulador, el formulario de pago cargaba bien (Brick
visible, se podían llenar los datos de la tarjeta), pero al tocar "Pagar"
se quedaba colgado en "Procesando pago..." para siempre, sin ningún error
visible ni ningún request nuevo en los logs del backend — ni siquiera uno
rechazado.

**Causa:** `mp_checkout_screen.dart` apunta al backend de desarrollo por
HTTP plano (`http://10.0.2.2:3000`, ver `ApiConfig`). El `POST
/pay/checkout` inicial (que pide el HTML del formulario) lo hace
`package:http` desde Dart — y ese **no pasa por el `NetworkSecurityConfig`
de Android**, así que funciona sin configuración extra. Pero una vez
cargado el HTML en el WebView, el `fetch('/api/events/.../requests')` que
dispara el Brick al tocar "Pagar" (ver `checkout.controller.js`, `onSubmit`)
corre DENTRO del WebView — que sí es un componente nativo de Android sujeto
al `NetworkSecurityConfig`, y desde Android 9 (API 28) el tráfico HTTP sin
cifrar está bloqueado por defecto para cualquier `targetSdkVersion` actual.
El `fetch` fallaba con `ERR_CLEARTEXT_NOT_PERMITTED` **antes de salir del
dispositivo**, por eso el backend nunca veía ni loggeaba nada.

**Qué se hizo:** se agregó
`android/app/src/main/res/xml/network_security_config.xml`, referenciado
desde `AndroidManifest.xml` (`android:networkSecurityConfig`), que permite
cleartext **solo** para `10.0.2.2` y `localhost` (los hosts de desarrollo
de `ApiConfig`) — no un `usesCleartextTraffic="true"` global, que dejaría
cualquier dominio sin cifrar. En producción (`ApiConfig._usarProduccion =
true`, Railway por HTTPS) esta excepción no aplica a nada: el dominio real
nunca está en esa lista.

**Por qué importa para la defensa:** es la misma lección que ya dejó el bug
del `onReady` del Brick (ver riesgo 8 del CLAUDE.md) — un fallo "silencioso"
de JavaScript dentro de un WebView no deja rastro en los logs de Flutter ni
del backend, porque pasa en un proceso de red completamente distinto
(Chromium del WebView, no el engine de Dart). `adb logcat` sigue siendo la
única forma real de ver qué pasó ahí dentro.

---

## 28. Más opciones para el Participante: historial de propinas y eliminar cuenta

**Qué se hizo:** dos agregados a Perfil, solo para Participante el primero,
para ambos roles el segundo:

- **Historial de propinas** (`GET /api/requests/mine`, sin `:eventId` —
  distinto del `GET /events/:eventId/requests/mine` que ya existía y está
  acotado a un solo evento): `requestModel.listarPorParticipante` hace
  JOIN con `events` para traer el nombre/código del evento de cada
  solicitud pasada, ordenado por fecha descendente. Nueva pantalla
  `ParticipantHistoryScreen`, con un resumen (canciones pedidas / total
  aportado en propinas aceptadas) arriba de la lista.
- **Eliminar cuenta** (`DELETE /api/auth/me`): si la cuenta tiene
  contraseña (no se creó con Google — ver `password_hash` en schema.sql),
  la vuelve a pedir antes de borrar nada; una cuenta de Google no tiene
  contraseña propia, así que ahí la sesión ya autenticada es la única
  confirmación posible. El borrado se apoya en los `ON DELETE CASCADE` que
  ya existían en `schema.sql` (`events.dj_id`, `song_requests.participante_id`,
  `transactions.request_id`) — no hace falta borrar nada a mano en el
  controller, Postgres deja todo consistente solo. Para un DJ, esto
  también borra sus eventos pasados (y con ellos las solicitudes/
  transacciones de esos eventos): es la contrapartida esperada de
  "eliminar cuenta", no un efecto secundario raro.

**Por qué importa para la defensa:** "eliminar cuenta" es el típico
requisito que se da por sentado pero nadie construye hasta que alguien
pregunta "¿y si un usuario quiere borrarse?" — queda como ejemplo de
cómo el modelo relacional con cascadas bien pensadas desde el principio
(ver riesgos del CLAUDE.md) hace que una función aparentemente grande
(borrar una cuenta y todo lo que depende de ella) sea en la práctica un
`DELETE FROM users WHERE id = $1` de una sola línea.

---

## 29. Géneros del evento: lista fija validada en el backend, no texto libre

**Qué se hizo:** al crear un evento, el DJ ahora elige (chips de
selección múltiple, mínimo 1) los géneros que van a sonar. Se guardan en
`events.generos` (`TEXT[]` en Postgres) y se muestran de vuelta al DJ (en
la lista de eventos y en la cola) y al Participante (en la tarjeta
"ESTÁS AQUÍ" antes de pedir una canción, para que sepa qué esperar).

Se eligió una lista fija (`GENEROS_VALIDOS` en `event.controller.js`,
duplicada como `_generosDisponibles` en `dj_events_screen.dart` — deben
quedar iguales) en vez de texto libre: el backend rechaza cualquier
género que no esté en esa lista (`400`). Es la misma lógica que ya se usa
para los montos de propina (múltiplos de $50, rango fijo) — una lista
fija es más fácil de mostrar como chips seleccionables, evita que cada DJ
escriba el mismo género de 5 formas distintas ("reggaeton", "Reggaetón",
"REGGAETON"), y deja la puerta abierta a filtrar eventos por género más
adelante si hace falta.

**Por qué importa para la defensa:** es deliberadamente informativo, no
restrictivo — elegir "Rock" no bloquea que alguien pida una canción de
otro género; la búsqueda de canciones (iTunes) sigue siendo libre. Mezclar
ambas cosas (restringir qué se puede pedir según el género declarado)
hubiera sido un acoplamiento innecesario para lo que se pidió.

---

## 30. Buscador de canciones acotado al género del evento (y por qué no hay filtro de idioma)

**Problema:** se pidió que los participantes de un evento solo vean, en su
buscador de canciones, resultados de los géneros que el DJ declaró al
crear el evento (ver decisión 29) — y de paso, si era posible armar
"temáticas" predefinidas tipo "solo música en inglés" o "solo géneros
latinos".

**Qué se investigó primero (importante para la defensa):** se probó a
mano contra la API real de iTunes antes de construir nada, porque el
comportamiento documentado no coincide con el real:
- El parámetro `genreId` de la **Search API** (`/search?term=...`) se
  probó con y sin él, mismo término, géneros distintos — **los resultados
  son idénticos**. La Search API lo ignora por completo en cuanto hay un
  `term` (que es obligatorio). No hay forma de pedirle a iTunes que
  filtre la búsqueda libre por género en el pedido mismo.
- El feed RSS de **Top Songs** (`/rss/topsongs/.../genre=X/json`), en
  cambio, **sí filtra de verdad** — se probó con varios `genre=X` y cada
  uno devuelve canciones genuinamente de ese género.
- **No existe ningún parámetro de idioma** en ninguna de las dos APIs. Por
  eso la temática "solo en inglés" no se implementó — hacerlo con una
  heurística (ej. country=US) habría dado resultados engañosos (mezcla de
  idiomas igual) en vez de simplemente no tener la función.

**Qué se hizo, con esa limitación real en mente:**
- **"Populares" (sin buscar):** filtro real, vía el feed RSS con
  `genre=X`. Si el evento declaró varios géneros que mapean a distintos
  `genreId` de iTunes, se piden varios feeds en paralelo y se intercalan
  (ver `topCancionesPorGeneros` en itunes.service.js).
- **Búsqueda libre (mientras la persona escribe):** filtro "mejor
  esfuerzo" hecho DESPUÉS de recibir los resultados — se pide de más
  (`limit * 4`) y se descarta lo que no coincide con el campo
  `primaryGenreName` que la Search API sí devuelve por canción (ver
  `buscarCancionesPorGeneros`). Nunca deja a alguien sin poder pedir una
  canción: si el filtrado deja la lista vacía, el mensaje se lo dice
  explícitamente en vez de mostrar una pantalla en blanco sin explicación.
- **Mapeo género BudSound → género iTunes:** aproximado, no una
  equivalencia exacta (`GENERO_A_ITUNES` en itunes.service.js) — por
  ejemplo, "Reggaetón", "Cumbia", "Salsa" y "Bachata" caen todos dentro
  del género amplio "Latin" de iTunes, que no los distingue entre sí.
- **Temáticas predefinidas:** no son géneros nuevos ni tocan el backend —
  son combos de un toque sobre los mismos `GENEROS_VALIDOS` ya existentes
  (`_temasPredefinidos` en `dj_events_screen.dart`, ej. "Solo géneros
  latinos" = Reggaetón+Cumbia+Salsa+Bachata).

**Por qué importa para la defensa:** mismo patrón que el riesgo de BPM
(decisión 26) — cuando se usa una API de terceros, probarla a mano antes
de construir sobre lo que *dice* la documentación que hace, porque acá
habría sido fácil escribir código contra un parámetro (`genreId` en
Search) que en la práctica no hace nada.

---

## 31. "Procesando pago..." colgado para siempre (round 2): el `fetch()` del WebView, no la red

**Problema:** después de arreglar el cleartext (decisión 27) y la RAM del
emulador, el pago seguía colgado — con el agravante de que ahora ni
siquiera había un crash o un timeout que lo explicara.

**Cómo se investigó (importante para la defensa — probar en capas, de
afuera hacia adentro):**
1. Se instrumentó `checkout.controller.js` con un timeout explícito de
   20s (`AbortController`) y un panel de texto en la propia página
   (`diag()`) que muestra cada paso: "Script cargado" → "Brick listo" →
   "onSubmit disparado" → "Llamando a /api/..." → (nunca llegaba más
   lejos, ni con éxito ni con error, ni siquiera tras los 20s del
   timeout).
2. Se probó el endpoint real (`POST /events/:id/requests`) directo por
   `curl`, con el mismo token y el mismo body que manda la página —
   **respondió en ~1 segundo**. El backend nunca fue el problema.
3. Conclusión: el `fetch()` de DENTRO del WebView hacia nuestro propio
   backend (`http://10.0.2.2:3000`, cleartext) se cuelga de forma
   silenciosa en esta versión de Chromium WebView embebido — ni error de
   red, ni el `AbortController` lo destraba. Es un problema específico de
   esa combinación (WebView + fetch + cleartext + este Android/Chromium),
   no de nuestro código de red en sí.

**Qué se hizo:** se sacó esa llamada del WebView por completo. Ahora:
- La página (`checkout.controller.js`) solo tokeniza la tarjeta con el
  Card Payment Brick y le pasa el token a Flutter por el canal
  `BudSoundCheckout` (`onSubmit` ya no hace `fetch`, solo
  `postMessage` + `resolve()`).
- `McpCheckoutScreen` (`mp_checkout_screen.dart`) es quien hace el
  `POST /events/:id/requests` de verdad, con `package:http` — el mismo
  cliente que **ya** se usaba sin problemas para pedir el HTML de la
  página (`_iniciar()`) y que nunca mostró este síntoma en ningún punto
  de esta sesión.
- La página recibe el resultado de vuelta con
  `window.budsoundResultado(ok, mensaje)` (Flutter llama a
  `controller.runJavaScript(...)`), así la persona sigue viendo "Listo."
  o el error en la misma pantalla, en vez de quedar en blanco.
- El token de checkout acotado (`emitirTokenCheckout`, 15 min, ver riesgo
  "revisión de seguridad" en CLAUDE.md) se mantiene — ahora lo usa
  directamente `McpCheckoutScreen` para autenticar su propio POST
  (`ApiClient.post(..., tokenPropio: ...)`), en vez de pasárselo a la
  página para que lo use en su `fetch()`. El WebView ya no recibe NINGÚN
  token de BudSound.

**Hallazgo aparte (no relacionado, pero se encontró al probar):** las
credenciales de MercadoPago en `.env` son de **producción**
(`MERCADOPAGO_ACCESS_TOKEN` empieza con `APP_USR-`), no de sandbox
(`TEST-...`). Por eso, aunque el cuelgue ya esté resuelto, pagar con una
tarjeta de prueba publicada (ej. `5416 7526 0258 2580` / titular `APRO`)
va a seguir fallando con `"Unauthorized use of live credentials"` — es
esperado, MercadoPago no deja usar tarjetas de prueba con credenciales
reales. Para probar el flujo completo hace falta reemplazar
`MERCADOPAGO_ACCESS_TOKEN`/`MERCADOPAGO_PUBLIC_KEY` en `.env` por las de
la pestaña **Credenciales de prueba** del panel de MercadoPago (no las de
producción que ya se usaron) — ver `.env.example`, que ya documentaba
esto correctamente con el prefijo `TEST-`.

**Por qué importa para la defensa:** cuando un `fetch()` dentro de un
WebView se comporta distinto que el mismo request hecho por Dart o por
`curl`, el problema casi nunca es "la red" — es el WebView como
plataforma. Mover la llamada de red fuera del WebView (dejándolo solo
para lo que un WebView tiene que hacer sí o sí: cargar el SDK de un
tercero y tokenizar datos sensibles) es más robusto que seguir
depurando un `fetch()` que, al día de hoy, no se pudo explicar por qué
se cuelga exactamente — y no hacía falta explicarlo del todo para
sacarlo de la ecuación.

---

## 32. La causa real del cuelgue: `onSubmit` del Brick mal desestructurado

**Esto corrige/completa la decisión 31.** Después de mover el POST del
WebView a Flutter (decisión 31), el pago seguía sin funcionar — pero esta
vez con una pista real en el panel de diagnóstico:
`unhandledrejection: Cannot read properties of undefined (reading 'token')`.

**La causa real, encontrada recién acá:** `checkout.controller.js` tenía
`onSubmit: ({ formData }) => ...` — pero el Card Payment Brick llama a
`onSubmit` pasando los datos de la tarjeta **directo como el argumento**,
no envueltos en `{ formData: ... }`. Desestructurar `{ formData }` de ahí
dejaba `formData` en `undefined`, y la primera línea que lo tocaba
(`formData.token`) tiraba esa excepción — **antes de llegar a intentar
nada de red**. Se corrigió a `onSubmit: (formData) => ...` (sin
desestructurar).

Esto probablemente era la causa real del "Procesando pago..." colgado
desde el principio de toda esta sesión de depuración — no el cleartext
(decisión 27), no la RAM del emulador, no el `fetch()` del WebView
(decisión 31). Esos tres eran problemas reales que valía la pena
arreglar igual, pero ninguno era la razón de que esto nunca funcionara:
el código nunca llegaba tan lejos como para toparse con ellos, porque se
caía antes, en una línea que ni siquiera hacía una llamada de red.

**Por qué importa para la defensa (la lección más importante de toda esta
sesión):** un error de JS atrapado silenciosamente por el propio Brick
(sin pasar por nuestro `onError`, porque pasó DENTRO de la promesa de
`onSubmit`, no al inicializar el Brick) puede producir un síntoma
idéntico a un cuelgue de red real — mismo "se queda pegado para
siempre", mismo "no hay ningún log en el backend". Sin el panel de
diagnóstico en pantalla (que loggea cada paso Y cualquier
`unhandledrejection`), esto podría haber quedado sin resolverse
indefinidamente, porque cada pista externa (RAM, cleartext, timing)
apuntaba hacia "problema de red" y ninguna apuntaba hacia "la forma del
argumento está mal". La lección: cuando algo "se cuelga" sin ningún
error, agregar instrumentación que capture errores no manejados
(`window.addEventListener('unhandledrejection', ...)`) antes de seguir
adivinando por capas de infraestructura (RAM, red, timeouts).

---

## 33. QR en una TV/tablet del local: una página pública, no una función de la app

**Problema:** se pidió una forma de mostrar el QR del evento en una
pantalla grande del local (TV, tablet en la entrada), no solo en el
celular del DJ.

**Qué se hizo:** `GET /display/:code` (`display.controller.js`) — una
página HTML pública, **sin login**, con el QR gigante, el nombre del
evento y el código en texto grande, pensada para quedar abierta en un
navegador y no tocarse más. Se accede desde la cola del DJ con el botón
"Mostrar en pantalla grande" (abre el link en el navegador del celular —
desde ahí se puede castear/espejar a una TV) o mandando el mismo link por
"Compartir código" para abrirlo directo en una tablet del local.

Decisiones de diseño, ambas para que funcione bien en un local real:
- El QR se genera como **SVG incrustado en el propio HTML** (paquete
  `qrcode`, server-side), no como imagen externa ni librería por CDN — la
  página no depende de que el local tenga internet de verdad, solo de
  llegar a este backend por la red local (igual que el resto de la app).
- **Sin autenticación**, a propósito: el código del evento ya es público
  por diseño (alcanza con verlo, escaneado o a mano, para unirse) — una
  TV en la entrada de un local no tiene cómo iniciar sesión, y exigirlo
  no agregaría ninguna seguridad real sobre lo que ese código ya permite.
- El tamaño del QR y del texto usa `clamp()` con unidades de viewport
  (`vw`/`vh`) en vez de un tamaño fijo, para que se vea bien tanto en una
  tablet como en una TV grande sin tener que detectar el dispositivo.

**Limitación conocida (entorno de desarrollo, no de la función en sí):**
en local, `ApiConfig` apunta a `10.0.2.2` (el emulador Android) o
`localhost` — ninguno de los dos es alcanzable desde una TV o tablet
*física* en la misma red WiFi. Para probar esto con un dispositivo real
hace falta la IP LAN de la máquina que corre el backend (ej.
`192.168.1.X:3000`) en vez de `localhost`. En producción (Railway
desplegado) esto no aplica — el dominio público ya es alcanzable desde
cualquier dispositivo.

---

## 34. Un DJ, un evento activo a la vez

**Qué se hizo:** `POST /api/events` ahora rechaza (409) crear un evento
nuevo si el DJ ya tiene uno `ACTIVO` (`eventModel.buscarActivoPorDj`,
`event.controller.js`). Del lado de la app, el botón "Crear evento" se
reemplaza por una tarjeta con acceso directo al evento activo en vez de
dejar que la persona lo intente y recién ahí se entere con un error.

**Por qué:** evita que alguien abra un evento nuevo por error (o desde
otro dispositivo con la misma cuenta) mientras el de verdad sigue
recibiendo solicitudes en otra pantalla — plata y solicitudes quedarían
repartidas entre dos eventos sin que nadie lo note de inmediato.

## 35. Nombre artístico editable, con condiciones (decisión del equipo)

**Qué se hizo:** el DJ puede cambiar su nombre artístico desde Perfil,
pero con dos condiciones combinadas (elegidas por el equipo entre varias
opciones):
- **Nunca con un evento activo** — evita que cambie de identidad a mitad
  de una transmisión en vivo mientras el QR ya está circulando con el
  nombre viejo.
- **Máximo 1 cambio cada 30 días** — mismo patrón que cambiar el nombre
  de usuario en redes sociales; evita que lo cambie seguido y confunda a
  participantes que ya lo conocen de eventos anteriores.

Ambas se validan en el backend (`auth.controller.js`,
`actualizarPerfil` — fuente de verdad) con una columna nueva,
`users.nombre_artistico_cambiado_at`. El cooldown de 30 días también se
calcula del lado de Flutter (ya viene en la sesión) para mostrar el
aviso sin pedirle nada al backend; la condición de "sin evento activo"
no se duplica en el cliente (no vale la pena pedir la lista de eventos
solo para eso) — si intenta cambiarlo igual, el error del backend se
muestra tal cual.

---

## 36. `Image.network` sin timeout colgó toda la app, no solo una carátula

**Problema:** al agregar carátulas a la cola del DJ (decisión de la
sesión anterior) y cargar canciones de prueba con URLs de verdad de
iTunes, la app completa dejó de responder a cualquier toque — no solo la
pantalla de la cola, **toda** la app, incluyendo cambiar de pestaña desde
Inicio. `adb logcat` mostró el tiempo de un solo frame subiendo de ~12s a
~67s (`EGL_emulation: app_time_stats`), con el proceso de la app vivo
pero el motor de Flutter completamente bloqueado — y la CPU del emulador
en 0% (no estaba la máquina sobrecargada, era un bloqueo real, no falta
de recursos).

**Causa:** `Image.network` usa por debajo el `HttpClient` de `dart:io`,
que **no tiene ningún timeout por defecto**. Si una sola URL nunca
responde (DNS que no resuelve, conexión que nunca cierra), esa carga de
imagen se queda colgada para siempre — y según se vio acá, eso puede
bloquear el motor de Flutter entero, no solo el widget de esa imagen en
particular.

**Qué se hizo (primer intento):** `widgets/network_artwork.dart` — un
widget nuevo que reemplazaba `Image.network` en los dos lugares donde se
usaba (cola del DJ y resultados de búsqueda del Participante). Pedía los
bytes con `package:http` y `.timeout(Duration(seconds: 6))` antes de
mostrar nada con `Image.memory`; si se vencía el timeout o fallaba,
mostraba el ícono de respaldo de siempre, sin arriesgar el resto de la
app.

**Revertido — decisión del equipo:** después de aplicar el fix, el
celular de prueba seguía sin responder. La causa más probable es que el
proceso ya estaba en el deadlock original (de antes del fix) y un
hot-reload no alcanza para recuperar un isolate ya colgado — hacía falta
matar el proceso entero (`adb shell am force-stop`) y recién ahí probar
de nuevo, paso que no se hizo a tiempo. En vez de seguir iterando sobre
esa teoría, se optó por sacar la función de carátulas por completo (no
solo protegerla con timeout): se borró `network_artwork.dart`, la cola
del DJ quedó sin ninguna miniatura de canción, y la búsqueda del
Participante volvió a su `Image.network` original (el mismo que ya tenía
antes de este incidente, sin tocar). **Riesgo aceptado, no resuelto:** la
búsqueda del Participante sigue usando `Image.network` sin timeout para
la carátula de cada resultado — el mismo patrón que causó el cuelgue,
solo que en un lugar que ya existía antes de este incidente y que nunca
dio problemas en la práctica. Si vuelve a congelarse la app durante una
búsqueda, revisar ahí primero antes de asumir que es un bug nuevo.

**Por qué importa para la defensa:** la causa real era muy fácil de
confundir con "el emulador está lento" o "problema de memoria" (ver
decisión 27, el bug de RAM anterior) — la señal que lo distinguió fue
revisar la CPU real del proceso del emulador en el host (0%, nada
sobrecargado) mientras el tiempo de frame de la app seguía subiendo: eso
apunta a un bloqueo genuino (esperando algo que nunca responde), no a
falta de recursos. Cualquier `Image.network`/`NetworkImage` sin timeout
en el código es un riesgo del mismo tipo — no son solo las carátulas de
canciones, aplica a cualquier imagen que venga de una URL externa.

---

## 37. Lista de eventos del DJ: historial agrupado y vista previa de solicitudes

**Qué se hizo:** en `DjEventsScreen`, la lista de eventos del DJ separa
los activos (como mucho uno, por la decisión 34) de los cerrados, y estos
últimos quedan bajo un encabezado colapsado visualmente "Historial (N)" en
vez de mezclados en una sola lista plana — con eventos de prueba y de
verdad acumulándose sprint a sprint, una lista plana se vuelve ilegible
rápido. Además, la tarjeta del evento activo muestra una vista previa de
hasta 3 solicitudes pendientes ("Llegando ahora") directo ahí, sin tener
que entrar a "Ver cola en vivo" para saber si hay algo nuevo.

**Por qué es "mejor esfuerzo":** la vista previa usa un `FutureBuilder`
que pide `RequestService.listarPorEvento` una vez por cada build de la
tarjeta — no hay un socket abierto en esta pantalla (la lista de eventos
no es la cola en vivo). Si llega una solicitud nueva, no aparece sola:
se actualiza la próxima vez que la lista se reconstruya (pull-to-refresh,
o volver a esta pestaña). Para algo en tiempo real de verdad está
`DjQueueScreen`, a un toque de distancia — esta vista previa es solo para
decidir de un vistazo si vale la pena entrar.

## 38. Temporizador de set del DJ: por qué vive en un singleton y no en la pantalla

**Qué se hizo:** el DJ puede configurar un temporizador (duraciones
rápidas: 15 min a 3 h) para controlar cuánto lleva tocando, con
pausa/reanudar y cuenta regresiva en vivo. El estado (duración, pausado,
tiempo restante) vive en `DjTimerService`, un singleton (`services/
dj_timer_service.dart`), no en el `State` de `DjQueueScreen`.

**Por qué:** la primera versión guardaba el temporizador en campos
locales de `_DjQueueScreenState` — funcionaba mientras el DJ se quedara
en esa pantalla, pero se reiniciaba apenas salía (ej. a revisar Perfil) y
volvía, porque `dispose()` destruye esos campos junto con el widget. Un
temporizador que se reinicia solo por cambiar de pestaña no sirve para su
propósito (controlar cuánto lleva tocando *en la noche*, no en esta
pantalla en particular). Moverlo a un singleton lo desacopla del ciclo de
vida de cualquier pantalla puntual.

**Detalle de diseño:** el tiempo restante se calcula contra una hora de
término real (`DateTime.now().add(duracion)`), no restando segundo a
segundo con un contador — así, si la UI deja de refrescarse un rato
(pantalla bloqueada, la pantalla que lo muestra no está montada), el
cálculo sigue siendo correcto al volver a leerlo, en vez de haberse
quedado pausado de hecho sin que nadie lo pidiera. Sigue siendo
**puramente local al dispositivo**, igual que antes: no se guarda en
disco ni se manda al backend, así que un cierre completo de la app sí lo
reinicia (aceptado — es una ayuda de pulso para la sesión actual, no un
dato del evento).

## 39. Vista previa del temporizador en "Inicio" y "En vivo": un widget con su propio tick

**Qué se hizo:** `widgets/dj_timer_chip.dart` — una versión compacta del
temporizador (ícono + cuenta regresiva, o nada si no hay uno activo) que
se insertó en el dashboard de "Inicio" y en la tarjeta del evento activo
de "En vivo", para que el DJ pueda seguir monitoreando cuánto lleva
tocando sin tener que entrar a la cola del evento.

**Por qué es un widget `Stateful` con su propio `Timer.periodic`, en vez
de pasarle el estado desde el padre:** ambas pantallas (`InicioScreen`,
`DjEventsScreen`) ya tienen su propio ciclo de carga (`FutureBuilder`,
`RefreshIndicator`) y no tenían ninguna razón previa para refrescarse una
vez por segundo. En vez de meterles un `Timer` a cada una solo para esto,
el chip se refresca a sí mismo leyendo `DjTimerService.instance` cada
segundo — cualquier pantalla puede usarlo con solo `const DjTimerChip()`,
sin cablear nada adicional, y si `DjTimerService` no tiene un
temporizador activo, el widget no ocupa espacio (`SizedBox.shrink()`).

## 40. Límite del filtro de género: iTunes no distingue Reggaetón de Salsa/Bachata/Cumbia

**Problema detectado:** un evento configurado solo con los géneros Salsa,
Bachata y Cumbia puede igual mostrar "Gasolina" de Daddy Yankee
(Reggaetón) en el buscador de canciones.

**Causa:** el filtro por género de la búsqueda libre (`buscarCancionesPorGeneros`,
`itunes.service.js`) funciona recortando DESPUÉS de recibir resultados,
revisando si el `primaryGenreName` que devuelve iTunes contiene alguno de
los nombres mapeados (ver decisión 30). El problema de fondo no es el
filtro en sí: es que **iTunes no tiene una categoría propia para
"Reggaetón"** — en su taxonomía, Reggaetón, Salsa, Bachata y Cumbia caen
todos bajo el mismo género amplio `"Latin"` (`GENERO_A_ITUNES` ya lo
documentaba así desde la decisión 30, pero no se había probado un caso
concreto hasta ahora). Como Salsa/Bachata buscan justo `"latin"` en el
nombre del género, cualquier canción de Reggaetón con esa misma etiqueta
pasa el filtro igual.

**No tiene arreglo real con la API gratuita actual:** la Search API de
iTunes no expone ningún subgénero más fino que "Latin" para esto — no es
un bug de filtrado, es un límite de qué datos entrega la fuente. Una
lista manual de artistas/términos de Reggaetón para excluir a mano sería
frágil (hay que mantenerla, y cualquier canción nueva o colaboración se
cuela). **Queda como limitación conocida, no resuelta:** el filtro de
género de la búsqueda libre es "mejor esfuerzo" y puede dejar pasar
canciones de géneros parecidos pero no declarados por el DJ, sobre todo
dentro del bloque "Latin". El DJ sigue siendo quien decide si acepta o
rechaza cada solicitud, así que esto no rompe el control artístico — solo
hace que el buscador no sea 100% preciso filtrando por género.

---

## 41. El temporizador "heredaba" el evento anterior: faltaba guardar a quién pertenece

**Problema:** el DJ cerraba un evento con el temporizador corriendo,
creaba uno nuevo, y el evento nuevo arrancaba con la cuenta regresiva del
anterior ya corriendo (o ya en cero).

**Causa:** `DjTimerService` (decisión 38) guardaba el temporizador en un
singleton para que sobreviviera a salir y volver a `DjQueueScreen` — pero
no guardaba a qué evento pertenecía, solo "hay un temporizador activo, sí
o no". Como el singleton no se reinicia solo al crear un evento nuevo
(¿por qué habría de hacerlo? nadie le avisa), cualquier pantalla que
preguntara "¿hay un temporizador activo?" recibía que sí, sin importar de
qué evento se tratara.

**Qué se hizo:** `DjTimerService` ahora guarda también el `eventoId` del
temporizador activo, y expone `activoPara(eventoId)` en vez de un simple
getter `activo` — cualquier pantalla que lo muestre (`DjQueueScreen`,
`DjTimerChip` en Inicio y En vivo) tiene que preguntar por el evento que
está mirando, no por el estado interno sin filtrar. Como un DJ no puede
tener dos eventos activos a la vez (decisión 34), sigue sin hacer falta
guardar un temporizador por evento — alcanza con que el que ya existe
"deje de aplicar" en cuanto se le pregunta por un evento distinto.

## 42. Imagen de evento: mismo patrón que la foto de perfil, sin bloquear nada

**Qué se hizo:** el DJ puede ponerle una imagen a un evento — al crearlo
(selector opcional en el diálogo de "Nuevo evento") o después, en
cualquier momento, tocando la imagen/código QR dentro de `DjQueueScreen`.
Se ve como miniatura en la lista de "En vivo" (`DjEventsScreen`, activos e
historial) y como banner grande en la cola del evento.

**Por qué el mismo patrón que `avatar_data_url` (decisión 11):** se guarda
como data URL (`data:image/...;base64,...`) directo en la fila de
`events` (columna `imagen_data_url`), no como archivo en disco — Railway
(free tier) tiene filesystem efímero, así que un archivo subido se
perdería en el próximo redeploy. Se extrajo a un helper compartido
(`utils/image_data_url.dart`) la detección de MIME por los primeros bytes
y la decodificación a `ImageProvider`, que antes solo existía duplicada
dentro de `profile_screen.dart` — ahora la usan ambos.

**Por qué no se bloquea con ninguna condición (a diferencia del nombre
artístico, decisión 35):** cambiarla o quitarla no confunde a nadie que
ya se unió — es solo una imagen de referencia, no una identidad. Se puede
tocar con el evento activo o ya cerrado, sin ningún cooldown.

**Detalle que costó encontrarlo:** el límite de tamaño de imagen
(`IMAGEN_EVENTO_MAX_LENGTH`, 3.5MB en base64) quedó por encima del límite
global del body parser de Express (`express.json({ limit: '3mb' })`,
puesto originalmente solo pensando en la foto de perfil de 2.8MB). Con
eso, una imagen de evento grande nunca llegaba a la validación propia del
controlador — Express la rechazaba antes, con un 413 genérico en vez del
mensaje claro de "imagen muy pesada". Se subió el límite global a 4mb
(con margen para el resto del body). Moraleja para la próxima vez que se
suba un límite de tamaño de archivo: revisar también el límite del body
parser global, no solo el límite propio del campo.

---

_Última actualización: se va completando a medida que aparecen más
decisiones de este tipo. Si el equipo agrega algo parecido, vale la pena
sumarlo acá con el mismo formato._
