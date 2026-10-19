# BudSound

App móvil para pedir canciones a un DJ en eventos en vivo mediante un
código QR, con una propina opcional al DJ. Reemplaza la interrupción
física al DJ ("oye, toca esta") por un canal digital y ordenado.

## Qué problema resuelve

En discotecas, bares y eventos en vivo, el público interrumpe físicamente
al DJ para pedir canciones — sin orden, sin registro y sin que el DJ
mantenga el control sobre su propio set. BudSound reemplaza eso por una
cola digital en tiempo real: el asistente escanea el QR del evento, pide
una canción con una propina opcional, y el DJ decide libremente si la
acepta o la rechaza.

## Integrantes y roles

| Integrante | Rol |
|---|---|
| Gabriel Sepúlveda | Product Owner — UI/UX y frontend del DJ |
| Danahe González | Scrum Master — backend, base de datos e integraciones |
| Benjamín Valenzuela | Equipo de desarrollo — pagos y frontend del Participante |

Es **una sola aplicación** con dos roles (Participante y DJ), no dos
productos separados — la interfaz cambia según el rol de la cuenta.

## Metodología

Scrum, con 7 sprints (Sprint 0 al 6) mapeados a las fechas del ramo, en 3
fases de evaluación a lo largo de 18 semanas.

## Arquitectura

Ninguna vista (Participante o DJ) accede directo a la base de datos ni a
APIs externas — todo pasa por el backend, que valida, autentica y
orquesta cada integración.

```
App (Flutter) ──HTTP/Socket.io──▶ Backend (Node.js + Express) ──▶ PostgreSQL
                                        │
                                        ├──▶ MercadoPago (pagos, OAuth split por DJ)
                                        ├──▶ iTunes Search API (metadatos de canciones)
                                        ├──▶ Deezer (BPM)
                                        ├──▶ Brevo (correo transaccional)
                                        └──▶ Google Sign-In (login alternativo)
```

Un mapa interactivo con el detalle de cada paso del flujo y cada pieza
técnica: https://claude.ai/artifact/LeYVJ2yWU2vuhcKQwX8f5D

Decisiones técnicas y de producto documentadas en [`CLAUDE.md`](CLAUDE.md)
y [`DECISIONES_TECNICAS.md`](DECISIONES_TECNICAS.md).

## Tecnologías

- **Frontend:** Flutter (Dart) — una sola base de código para ambos roles.
- **Backend:** Node.js + Express, sin ORM (SQL parametrizado con `pg`).
- **Base de datos:** PostgreSQL.
- **Tiempo real:** Socket.io (cola de solicitudes, una sala por evento).
- **Pagos:** MercadoPago (Payments API + OAuth marketplace para split por DJ).
- **Música:** iTunes Search API (metadatos) y Deezer (BPM) — nunca se
  reproduce audio dentro de la app.
- **Correo:** Brevo (API HTTP, verificación de cuenta y recuperación de
  contraseña).
- **Login:** correo/contraseña o Google Sign-In (OAuth).
- **Hosting:** Railway (backend + PostgreSQL en producción).

## Cómo correr el proyecto localmente

Con Docker (recomendado — levanta el backend y PostgreSQL juntos):

```bash
cd budsound_backend
cp .env.example .env   # completa las variables que tengas; el resto queda inactivo sin romper nada
cd ..
docker compose up -d
docker compose exec backend npm run db:migrate   # una sola vez, crea las tablas
```

El backend queda en `http://localhost:3000` (healthcheck: `GET /api/health`).
Para levantar también Adminer (visor web de la base de datos) en
`http://localhost:8080`: `docker compose --profile tools up -d`.

Para la app Flutter, ver [`budsound_app/README.md`](budsound_app/README.md).

Sin Docker (alternativa), ver la guía manual en
[`budsound_backend/README.md`](budsound_backend/README.md).

## Despliegue a producción

Ver [`RAILWAY_DEPLOY.md`](RAILWAY_DEPLOY.md).
