# budsound-backend

API de BudSound: autenticación con rol, eventos con código para QR, cola de
solicitudes de canciones en tiempo real y cobro condicionado (solo se cobra
si el DJ acepta la solicitud).

## Stack

Node.js + Express, PostgreSQL (`pg`, sin ORM), Socket.io para la cola en
vivo, iTunes Search API para metadatos de canciones, MercadoPago para el
cobro (pendiente de credenciales de sandbox — ver `.env.example`).

## Cómo correr en local

```bash
npm install
cp .env.example .env   # completa DATABASE_URL y JWT_SECRET
npm run db:migrate     # crea las tablas en PostgreSQL
npm run dev
```

El servidor queda en `http://localhost:3000`. Healthcheck: `GET /api/health`.

## Estructura

```
src/
  config/     # env y conexión a PostgreSQL
  db/         # schema.sql y script de migración
  middleware/ # auth (JWT) y manejo de errores
  models/     # acceso a datos (SQL parametrizado, sin ORM)
  services/   # iTunes y MercadoPago (integraciones externas)
  controllers/
  routes/
  sockets/    # salas de Socket.io por evento (event:<id>)
```

## Endpoints principales

- `POST /api/auth/register` / `POST /api/auth/login` / `GET /api/auth/me`
- `POST /api/events` (DJ) — crea evento y devuelve `code` para el QR
- `GET /api/events/code/:code` — el Participante resuelve el QR escaneado
- `GET /api/events/mine`, `PATCH /api/events/:id/close`, `GET /api/events/:id/summary`
- `POST /api/events/:eventId/requests` (Participante) — solicita canción con monto opcional
- `GET /api/events/:eventId/requests` (DJ) — cola de solicitudes
- `PATCH /api/requests/:id/accept` / `PATCH /api/requests/:id/reject` (DJ)
- `GET /api/songs/search?q=...` — proxy de iTunes Search API

## Tiempo real

El cliente se conecta a Socket.io con `auth: { token: <jwt> }`, emite
`event:join`/`event:leave` con el id del evento, y escucha `request:created`
y `request:resolved` para mantener la cola sincronizada sin hacer polling.

## Pendiente

- Integración real de MercadoPago cuando existan credenciales de sandbox
  (`src/services/mercadopago.service.js` tiene el stub y el TODO).
- Webhook de confirmación de pago de MercadoPago para marcar `transactions`
  como `APROBADA`.
