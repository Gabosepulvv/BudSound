# budsound-backend

API de BudSound: autenticación con rol, eventos con código para QR, cola de
solicitudes de canciones en tiempo real y cobro condicionado (solo se cobra
si el DJ acepta la solicitud).

## Stack

Node.js + Express, PostgreSQL (`pg`, sin ORM), Socket.io para la cola en
vivo, iTunes Search API para metadatos de canciones, Deezer para el BPM,
MercadoPago para el cobro (Payments API + OAuth marketplace para que cada
DJ cobre en su propia cuenta), Brevo para el correo transaccional (API
HTTP, no SMTP) y Google Sign-In como login alternativo.

Cada integración se activa sola apenas sus credenciales existen en
`.env` — sin ellas, esa capa queda inactiva y el resto de la app sigue
funcionando igual (ver `.env.example`).

## Cómo correr en local

**Recomendado:** desde la raíz del repo, con Docker — ver el
[`README.md` raíz](../README.md). Levanta el backend y PostgreSQL juntos
con `docker compose up -d`.

**Alternativa manual**, sin Docker Compose (necesitas PostgreSQL corriendo
en algún lado, por ejemplo con `docker run`):

```bash
docker run -d --name budsound-postgres \
  -e POSTGRES_USER=budsound \
  -e POSTGRES_PASSWORD=budsound \
  -e POSTGRES_DB=budsound \
  -p 5432:5432 \
  postgres:16-alpine
```

Después, en `budsound_backend/`:

```bash
npm install
cp .env.example .env
# DATABASE_URL=postgresql://budsound:budsound@localhost:5432/budsound
# JWT_SECRET=cualquier-string-para-desarrollo
npm run db:migrate     # crea las tablas en PostgreSQL
npm run dev
```

El servidor queda en `http://localhost:3000`. Healthcheck (verifica también
la conexión a la BD): `GET /api/health`.

## Estructura

```
src/
  config/     # env y conexión a PostgreSQL
  db/         # schema.sql y script de migración
  middleware/ # auth (JWT) y manejo de errores
  models/     # acceso a datos (SQL parametrizado, sin ORM)
  services/   # iTunes, Deezer, MercadoPago, Brevo y Google (integraciones externas)
  controllers/
  routes/
  sockets/    # salas de Socket.io por evento (event:<id>)
  jobs/       # barridos periódicos (limpieza de solicitudes colgadas)
```

## Endpoints principales

- `POST /api/auth/register` / `POST /api/auth/login` / `GET /api/auth/me`
- `GET /api/auth/verify-email` — confirma la cuenta desde el link del correo (Brevo)
- `POST /api/auth/google` — login/registro con Google Sign-In
- `POST /api/auth/forgot-password` / `POST /api/auth/reset-password` — recuperación de contraseña
- `PATCH /api/auth/me` — edita nombre/apellido y/o la foto de perfil (`avatarDataUrl`, un data URL base64 de hasta ~2MB; `null` la quita)
- `POST /api/events` (DJ) — crea evento y devuelve `code` para el QR
- `GET /api/events/code/:code` — el Participante resuelve el QR escaneado
- `GET /api/events/mine`, `PATCH /api/events/:id/close`, `GET /api/events/:id/summary`, `GET /api/events/stats/mine` (estadísticas de toda la carrera del DJ)
- `POST /api/events/:eventId/requests` (Participante) — solicita canción con monto obligatorio
- `GET /api/events/:eventId/requests` (DJ) — cola de solicitudes
- `GET /api/events/:eventId/requests/mine` (Participante) — solo sus propias solicitudes en ese evento
- `PATCH /api/requests/:id/accept` / `PATCH /api/requests/:id/reject` (DJ)
- `PATCH /api/requests/:id/played` (DJ) — marca la canción como reproducida (evidencia con timestamp para un eventual contracargo)
- `GET /api/songs/search?q=...` — proxy de iTunes Search API (incluye el BPM vía Deezer)
- `GET /api/dj/mercadopago/connect` / `GET /api/dj/mercadopago/callback` / `GET /api/dj/mercadopago/status` — OAuth para que el DJ conecte su propia cuenta
- `GET /api/requests/:id/payment` (Participante) — estado de su transacción
- `GET /api/payment-mode` — si hay credenciales reales de MercadoPago cargadas (si no, la app confirma una propina simulada)
- `POST /api/webhooks/mercadopago` — receptor del webhook real de notificaciones de pago

## Tiempo real

El cliente se conecta a Socket.io con `auth: { token: <jwt> }`, emite
`event:join`/`event:leave` con el id del evento, y escucha `request:created`
y `request:resolved` para mantener la cola sincronizada sin hacer polling.

## Limpieza automática de solicitudes colgadas

`src/jobs/cleanupRequests.js` corre un barrido cada `CLEANUP_INTERVAL_MINUTES`
(default 1 min, y una vez al arrancar el servidor): cancela toda solicitud
`PENDIENTE` cuyo evento ya cerró, o que lleva más de `REQUEST_TIMEOUT_MINUTES`
(default 7 min) sin que el DJ responda. Pasa a estado `CANCELADA` (distinto de
`RECHAZADA`, que es una decisión activa del DJ) y avisa por Socket.io
(`request:resolved`) a quien esté viendo ese evento. Nunca depende de que
alguien lo dispare a mano — ver CLAUDE.md, riesgo "Autorización de pago vs.
captura".

## Pendiente

- Verificación formal de Google (la pantalla de consentimiento OAuth ya
  está en modo producción, pero sin pasar por la revisión completa de
  Google todavía).
- Que una cuenta real de DJ quede habilitada por MercadoPago para recibir
  pagos (ver CLAUDE.md, riesgo "¿A quién le llega la plata primero?").
