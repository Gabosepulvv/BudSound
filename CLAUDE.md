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

## Stack técnico

- **Frontend:** Flutter — una sola base de código para las vistas de
  Participante y DJ.
- **Backend:** Node.js + Express.
- **Base de datos:** PostgreSQL (modelo relacional: usuarios, eventos,
  solicitudes, transacciones).
- **Tiempo real:** Socket.io, para la cola de solicitudes en vivo.
- **Pagos:** MercadoPago (Checkout API / Checkout Pro). **Cambiaron desde
  Transbank Webpay** — cualquier código, doc o mockup viejo que mencione
  Transbank está desactualizado, ya no aplica.
  - Aún no tienen credenciales de sandbox de MercadoPago — la integración
    debe quedar con variables de entorno placeholder
    (`MERCADOPAGO_ACCESS_TOKEN`, `MERCADOPAGO_PUBLIC_KEY`) fáciles de
    reemplazar cuando las obtengan.
- **API musical:** iTunes Search API (gratuita, sin key).
- **Hosting:** Railway (capa gratuita).

## Arquitectura — regla clave

Ninguna vista (Participante o DJ) accede directamente a la base de datos ni
a APIs externas (MercadoPago, iTunes). **Todo pasa por el backend**, que es
quien valida, autentica y orquesta esas integraciones.

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

## Convenciones (ir completando a medida que el equipo decida)

- Idioma del código (nombres de variables, funciones): inglés.
- Idioma de comentarios y documentación: español.
- Commits: seguir un formato consistente (a definir por el equipo — sugerido
  Conventional Commits).
- Este archivo se debe mantener al día si cambia una decisión de arquitectura
  o de negocio — es la fuente de verdad para cualquiera (o cualquier
  instancia de Claude Code) que entre a este repo por primera vez.
