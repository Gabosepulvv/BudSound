# budsound-backend

API de BudSound: autenticación con rol, eventos con código para QR, cola de
solicitudes de canciones en tiempo real y cobro condicionado (solo se cobra
si el DJ acepta la solicitud).

## Stack

Node.js + Express, PostgreSQL (`pg`, sin ORM), Socket.io para la cola en
vivo, iTunes Search API para metadatos de canciones, MercadoPago para el
cobro (pendiente de credenciales de sandbox — ver `.env.example`).

## Cómo correr en local

Necesitas Docker Desktop abierto (una sola vez, no hay que instalar
PostgreSQL en tu máquina):

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

Para volver a levantar el contenedor otro día (ya no hace falta crearlo de
nuevo): `docker start budsound-postgres`.

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
- `GET /api/requests/:id/payment` (Participante) — estado de su transacción
- `POST /api/requests/:id/payment/simulate-approval` (Participante) — simula la aprobación del pago mientras no haya credenciales reales de MercadoPago (se elimina cuando se integre el gateway real)
- `POST /api/webhooks/mercadopago` — receptor del webhook real (sin auth, stub por ahora)

## Tiempo real

El cliente se conecta a Socket.io con `auth: { token: <jwt> }`, emite
`event:join`/`event:leave` con el id del evento, y escucha `request:created`
y `request:resolved` para mantener la cola sincronizada sin hacer polling.

## Pendiente

- Integración real de MercadoPago cuando existan credenciales de sandbox
  (`src/services/mercadopago.service.js` tiene el stub y el TODO). El
  webhook (`src/controllers/payment.controller.js`) ya está enrutado pero
  solo loguea la notificación — falta validar contra la API de MercadoPago
  y actualizar `transactions.status` según el pago real.
- Mientras no haya credenciales, `POST /api/requests/:id/payment/simulate-approval`
  permite demostrar el flujo completo aceptar → pagar → aprobado.
