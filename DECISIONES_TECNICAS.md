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

---

_Última actualización: se va completando a medida que aparecen más
decisiones de este tipo. Si el equipo agrega algo parecido, vale la pena
sumarlo acá con el mismo formato._
