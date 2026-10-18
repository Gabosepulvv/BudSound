# Guía paso a paso: desplegar el backend de BudSound en Railway

Esta guía cubre solo el **backend** (`budsound_backend/`) + una base de
datos PostgreSQL administrada. La app Flutter no se despliega en Railway —
se sigue compilando como APK/instalable y se distribuye aparte; lo único
que cambia en ella es la URL a la que apunta (último paso de esta guía).

Railway ya no tiene un plan gratis de verdad: el más barato es el plan
"Pasatiempo" (Hobby), $5 USD/mes de uso mínimo. Para este proyecto (una
API chica + Postgres pequeño, sin tráfico real salvo pruebas y la
demo/defensa) sobra de lejos — nunca se acerca a los límites de ese plan.

## 0. Antes de empezar

- Ten a mano una cuenta de GitHub (Railway se conecta directo al repo
  `Gabosepulvv/BudSound`, ya está todo subido).
- El repo tiene **dos proyectos en una sola carpeta** (`budsound_backend/`
  y `budsound_app/`) — el paso 2 explica cómo decirle a Railway que solo
  construya el backend.

## 1. Crear el proyecto en Railway

1. Entra a [railway.app](https://railway.app/) e inicia sesión con GitHub
   (lo más simple: así Railway ya tiene permiso para leer tus repos).
2. **New Project → Deploy from GitHub repo**.
3. Elige el repositorio `Gabosepulvv/BudSound`. Si no aparece, usa
   "Configure GitHub App" para darle acceso a ese repo específico.
4. Railway va a crear un primer **servicio** apuntando a la raíz del repo
   — lo vamos a configurar en el paso siguiente (todavía no va a
   funcionar porque la raíz no tiene `package.json`).

## 2. Apuntar el servicio a `budsound_backend/`

Como el `package.json` está en una subcarpeta, hay que decirle a Railway
dónde está:

1. Dentro del proyecto recién creado, click en el servicio (la cajita con
   el nombre del repo) → pestaña **Settings**.
2. Busca **Root Directory** (sección "Source" o "Build") y escribe:
   ```
   budsound_backend
   ```
3. En la misma pestaña, confirma que:
   - **Build Command**: vacío (Railway detecta Node.js automáticamente
     via Nixpacks y corre `npm install` solo).
   - **Start Command**: `npm start` (ya está definido en
     `budsound_backend/package.json` → corre `node src/server.js`).
4. Guarda. Railway va a intentar un primer deploy — va a fallar todavía
   porque faltan las variables de entorno (paso 4).

## 3. Agregar PostgreSQL

1. Dentro del mismo proyecto de Railway: **+ New → Database → Add
   PostgreSQL**.
2. Railway crea un servicio de Postgres aparte y genera automáticamente
   una variable `DATABASE_URL` — pero esa variable vive en el servicio de
   Postgres, no en el del backend. Hay que conectarlos:
   - Click en el servicio del **backend** → pestaña **Variables** →
     **+ New Variable → Add Reference** → elige el servicio de Postgres →
     variable `DATABASE_URL`.
   - Esto deja `DATABASE_URL` disponible en el backend sin copiar el
     valor a mano (si cambia, se actualiza solo).

## 4. Variables de entorno del backend

En el servicio del backend → pestaña **Variables**, agrega estas (además
de `DATABASE_URL`, ya resuelta en el paso 3). Son las mismas de
`budsound_backend/.env.example`:

| Variable | Valor sugerido | Nota |
|---|---|---|
| `NODE_ENV` | `production` | |
| `CORS_ORIGIN` | `*` | La app es móvil, no hay un origen de navegador que restringir; si más adelante agregan un frontend web propio, cambiar a su dominio exacto. |
| `JWT_SECRET` | *(genera uno)* | **No reutilices** el de `.env` local — genera uno nuevo y largo, ej. con `openssl rand -hex 32` o cualquier generador de contraseñas. |
| `JWT_EXPIRES_IN` | `7d` | |
| `GOOGLE_CLIENT_ID` | *(el Client ID "Web" de Google Cloud Console)* | Ver sección "Login con Google — setup pendiente" en `CLAUDE.md`. Si todavía no lo tienen, dejar vacío — el login con Google queda inactivo pero el resto de la app funciona igual. |
| `MERCADOPAGO_ACCESS_TOKEN` | *(token de sandbox o producción)* | Dejar el placeholder de `.env.example` mientras no tengan credenciales reales. |
| `MERCADOPAGO_PUBLIC_KEY` | *(idem)* | |
| `MERCADOPAGO_CLIENT_ID` | *(Client ID OAuth)* | Opcional — solo para el split de pagos por DJ. Dejar vacío desactiva el botón "Conectar MercadoPago" (el cobro sigue funcionando en la cuenta central). |
| `MERCADOPAGO_CLIENT_SECRET` | *(Client Secret OAuth)* | Idem, pestaña "OAuth" de las credenciales de tu app en MercadoPago — ver CLAUDE.md. |
| `BREVO_API_KEY` / `EMAIL_SENDER` / `EMAIL_SENDER_NAME` | *(ver `.env.example`)* | Opcional — solo para verificación de correo al registrarse. Vacío = el registro no exige verificar el correo (como ahora en local). **No uses SMTP directo acá:** Railway bloquea el tráfico saliente por los puertos SMTP por completo (confirmado 2026-10-18) — por eso el correo va por la API HTTP de Brevo en vez de por `nodemailer`/Gmail. |
| `PUBLIC_URL` | *(se completa en el paso 6)* | Tiene que ser el dominio público que Railway genera para este mismo servicio, con `https://` — hace falta primero generar el dominio (paso 6) y volver acá a pegarlo. |
| `BUDSOUND_COMMISSION_RATE` | `0.08` | |
| `REQUEST_TIMEOUT_MINUTES` | `7` | |
| `CLEANUP_INTERVAL_MINUTES` | `1` | |

`PORT` **no** se agrega a mano — Railway la inyecta solo y el backend ya
la lee (`env.js` → `process.env.PORT`).

## 5. Aplicar el esquema de la base de datos

La base de Postgres que creó Railway está vacía — hay que correr
`schema.sql` una vez. Dos formas:

**Opción A — desde tu máquina (más simple):**

1. En el servicio de Postgres → pestaña **Connect**, copia la
   "Postgres Connection URL" (la externa, la que empieza con
   `postgresql://...proxy.rlwy.net...`).
2. En tu terminal, dentro de `budsound_backend/`:
   ```bash
   DATABASE_URL="<pega la URL de Railway>" npm run db:migrate
   ```
   Esto corre `src/db/migrate.js`, que aplica `schema.sql` completo contra
   esa base.

**Opción B — desde la consola de Railway:** el servicio de Postgres tiene
una pestaña **Data** con un editor de queries donde puedes pegar el
contenido de `budsound_backend/src/db/schema.sql` directamente.

## 6. Verificar que el backend quedó arriba

1. En el servicio del backend → pestaña **Settings** → **Networking** →
   **Generate Domain**. Railway asigna una URL pública del tipo
   `budsound-backend-production.up.railway.app`.
2. Espera a que el deploy termine (pestaña **Deployments**, el más
   reciente debe quedar en verde/"Success").
3. Abre `https://<tu-dominio>.up.railway.app/api/health` en el navegador
   — debe responder `{"ok":true,"db":"up"}`. Si `db` no es `up`, revisa
   que `DATABASE_URL` esté bien referenciada (paso 3) y que el esquema se
   haya aplicado (paso 5).

## 7. Apuntar la app Flutter al backend ya desplegado

Edita `budsound_app/lib/core/api_config.dart`:

```dart
static const bool _usarProduccion = true; // era false
static const String _hostProduccion = 'budsound-backend-production.up.railway.app'; // tu dominio real, sin https:// ni / al final
```

Con `_usarProduccion = true`, la app arma todas sus URLs con `https://` y
sin puerto (Railway lo maneja detrás de su proxy). Mientras tanto, pueden
seguir alternando: `false` para seguir probando contra el backend local
(`localhost`/`10.0.2.2`) durante desarrollo, `true` solo para compilar el
build que van a repartir para la demo/defensa.

Después de cambiar el flag, recompilar (`flutter run` o
`flutter build apk`) — es un valor en tiempo de compilación, no se
actualiza solo.

## 8. Checklist final antes de la demo

- [ ] `https://<dominio>/api/health` responde `db: "up"`.
- [ ] Crear un evento de prueba desde la app (con `_usarProduccion = true`)
      y confirmar que aparece en la cola del DJ en tiempo real (prueba que
      Socket.io también está pasando por el proxy de Railway sin problema
      — usa el mismo dominio/puerto que el HTTP normal, no necesita config
      aparte).
- [ ] Revisar en Railway → backend → **Metrics** que no se esté acercando
      al límite de créditos gratis si van a dejarlo corriendo varios días
      seguidos antes de la defensa.

## Notas / troubleshooting

- **Error `ECONNREFUSED` o `self-signed certificate` al correr
  `db:migrate` contra Railway:** usa la URL de conexión **externa**
  (`...proxy.rlwy.net...`) del paso 5, no la interna
  (`...railway.internal`) — esa última solo funciona entre servicios
  dentro de Railway, no desde tu máquina.
- **El deploy falla con `Cannot find module`:** casi siempre significa que
  el **Root Directory** (paso 2) no quedó apuntando a `budsound_backend` —
  Railway está intentando correr `npm install` en la raíz del repo, donde
  no hay `package.json`.
- **MercadoPago/Google Sign-In no funcionan en producción:** esperado si
  dejaron esas variables como placeholder (paso 4) — el resto de la app
  (eventos, cola, solicitudes) funciona igual sin ellas.
