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

---

_Última actualización: se va completando a medida que aparecen más
decisiones de este tipo. Si el equipo agrega algo parecido, vale la pena
sumarlo acá con el mismo formato._
