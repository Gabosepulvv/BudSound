-- Esquema relacional de BudSound.
-- Cobrar por reproducir una canción específica viola los ToS de Spotify/YouTube,
-- así que "monto" es siempre una propina/incentivo al DJ, nunca una garantía
-- de reproducción (ver CLAUDE.md, sección "Decisión legal").

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('PARTICIPANTE', 'DJ');
CREATE TYPE event_status AS ENUM ('ACTIVO', 'CERRADO');
-- CANCELADA: el sistema la cerró sola (evento cerrado o vencimiento de
-- horas sin respuesta), a diferencia de RECHAZADA que es una decisión
-- activa del DJ (ver CLAUDE.md, riesgo "Autorización de pago vs. captura").
CREATE TYPE request_status AS ENUM ('PENDIENTE', 'ACEPTADA', 'RECHAZADA', 'CANCELADA');
-- AUTORIZADA: MercadoPago retuvo el monto pero todavía no se cobró
-- (captura diferida, ver CLAUDE.md riesgo "Autorización de pago vs.
-- captura") — pasa a APROBADA cuando el DJ acepta (se captura) o a
-- RECHAZADA cuando rechaza, se vence el plazo, o el pago fue rechazado de
-- entrada por MercadoPago.
CREATE TYPE transaction_status AS ENUM ('PENDIENTE', 'AUTORIZADA', 'APROBADA', 'RECHAZADA');

CREATE TABLE users (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email             TEXT NOT NULL UNIQUE,
  -- NULL cuando la cuenta se creó con "Iniciar sesión con Google" (no tiene
  -- contraseña propia) — iniciarSesion() lo rechaza explícitamente en ese
  -- caso en vez de comparar contra un hash inexistente.
  password_hash     TEXT,
  role              user_role NOT NULL DEFAULT 'PARTICIPANTE',
  nombre            TEXT NOT NULL,
  apellido          TEXT NOT NULL,
  nombre_artistico  TEXT,
  -- Último cambio de nombre_artistico — el DJ solo puede cambiarlo sin un
  -- evento activo y como máximo una vez cada 30 días (ver
  -- auth.controller.js, `actualizarPerfil`). NULL = nunca lo cambió desde
  -- que se registró, así que no aplica el cooldown todavía.
  nombre_artistico_cambiado_at TIMESTAMPTZ,
  -- Data URL (data:image/...;base64,...) de la foto de perfil. Se guarda
  -- directo en la fila en vez de un archivo en disco porque Railway (free
  -- tier) tiene filesystem efímero — un archivo subido se perdería en el
  -- próximo redeploy.
  avatar_data_url   TEXT,
  -- Confirma que la persona es dueña del correo con el que se registró (no
  -- aplica a cuentas creadas con Google, que llegan ya verificadas porque
  -- Google confirma el email por su cuenta — ver auth.controller.js). Antes
  -- de esto, cualquiera podía registrarse con el correo de otra persona sin
  -- que nada lo confirmara.
  email_verificado  BOOLEAN NOT NULL DEFAULT false,
  verificacion_token_hash    TEXT,
  verificacion_token_expira  TIMESTAMPTZ,
  -- Mismo patrón que el token de verificación de arriba (hash, nunca el
  -- token en texto plano; expira solo) — para el link de "olvidé mi
  -- contraseña" que llega por correo (ver auth.controller.js,
  -- `solicitarRecuperacion`/`restablecerPassword`).
  reset_password_token_hash    TEXT,
  reset_password_token_expira  TIMESTAMPTZ,
  -- OAuth de MercadoPago como marketplace (solo DJ): con esto conectado,
  -- las propinas de sus eventos se cobran directo en SU cuenta (menos la
  -- comisión de BudSound vía `application_fee`) en vez de pasar por la
  -- cuenta central de BudSound — ver CLAUDE.md, "¿A quién le llega la
  -- plata primero?" (Opción A) y mercadopago-oauth.service.js.
  mp_collector_id      BIGINT,
  mp_access_token      TEXT,
  mp_refresh_token     TEXT,
  mp_token_expira      TIMESTAMPTZ,
  -- Nickname/correo de la cuenta de MercadoPago conectada — se muestran en
  -- Perfil para que el DJ pueda verificar que quedó la cuenta correcta
  -- (sin esto, no hay forma de distinguir una cuenta de otra a simple
  -- vista, solo un ID numérico).
  mp_nickname          TEXT,
  mp_email             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dj_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code          TEXT NOT NULL UNIQUE, -- valor que se codifica en el QR
  nombre        TEXT NOT NULL,
  -- Hora de inicio/término que el DJ declara al crear el evento — es
  -- informativa (se muestra al público y al propio DJ), no cierra el
  -- evento sola al llegar la hora: el cierre real sigue siendo manual
  -- (`PATCH /events/:id/close`) o por el cron de solicitudes colgadas.
  hora_inicio   TIME,
  hora_fin      TIME,
  -- Fecha(s) real(es) del evento (no cuándo se creó el registro en la
  -- app) — para que el DJ pueda saber, meses después, qué día fue tal
  -- evento al revisar su historial en Perfil. Iguales para un evento de
  -- un solo día; `fecha_fin` > `fecha_inicio` para uno de varios días.
  -- Nullable porque los eventos creados antes de esta columna no la
  -- tienen — el historial cae de vuelta a `created_at` para esos.
  fecha_inicio  DATE,
  fecha_fin     DATE,
  -- Géneros que el DJ declara para el evento (lista fija, ver
  -- GENEROS_VALIDOS en event.controller.js) — informativo para quien se
  -- une, no restringe qué puede pedirse (la búsqueda de canciones sigue
  -- siendo libre vía iTunes).
  generos       TEXT[] NOT NULL DEFAULT '{}',
  -- Data URL (data:image/...;base64,...) de la imagen del evento —
  -- opcional, mismo patrón que `avatar_data_url` de `users`: se guarda
  -- directo en la fila en vez de un archivo en disco porque Railway
  -- (free tier) tiene filesystem efímero.
  imagen_data_url TEXT,
  status        event_status NOT NULL DEFAULT 'ACTIVO',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at     TIMESTAMPTZ
);

CREATE TABLE song_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  participante_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  itunes_track_id   BIGINT NOT NULL,
  titulo            TEXT NOT NULL,
  artista           TEXT NOT NULL,
  artwork_url       TEXT,
  -- La propina es obligatoria para pedir una canción (decisión post-MVP —
  -- antes era opcional, ver DECISIONES_TECNICAS.md). Múltiplo de 50 para
  -- que el monto se pueda pagar en efectivo sin vueltas raras: termina en
  -- 0 y la decena es 0 o 5 (ej. 600, 650, 700).
  monto_clp         INTEGER NOT NULL CHECK (monto_clp BETWEEN 500 AND 20000 AND monto_clp % 50 = 0),
  -- El participante debe aceptar explícitamente que no hay devolución una
  -- vez que el DJ acepta (riesgo "El participante pide la devolución del
  -- dinero" en CLAUDE.md) — ahora siempre obligatorio, toda solicitud lleva
  -- propina.
  terminos_aceptados BOOLEAN NOT NULL CHECK (terminos_aceptados = true),
  -- BPM de la canción según Deezer (ver deezer.service.js) — "mejor
  -- esfuerzo", nulo si Deezer no tiene la canción, no la analizó, o no
  -- respondió a tiempo. Se calcula una sola vez al crear la solicitud (no
  -- en cada carga de la cola) para que el DJ vea el ritmo de lo que le
  -- piden y pueda mezclar sin tener que buscarlo a mano.
  bpm               INTEGER,
  status            request_status NOT NULL DEFAULT 'PENDIENTE',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at       TIMESTAMPTZ,
  -- Timestamp que el DJ marca cuando efectivamente suena la canción.
  -- Es la evidencia interna para disputar un contracargo de MercadoPago
  -- (riesgo "Contracargo" en CLAUDE.md) — "toqué la canción" es difícil
  -- de probar sin un registro con hora exacta.
  reproducida_at    TIMESTAMPTZ
);

CREATE TABLE transactions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id        UUID NOT NULL UNIQUE REFERENCES song_requests(id) ON DELETE CASCADE,
  monto_bruto_clp   INTEGER NOT NULL,
  comision_clp      INTEGER NOT NULL,
  monto_neto_clp    INTEGER NOT NULL,
  status            transaction_status NOT NULL DEFAULT 'PENDIENTE',
  mp_payment_id     TEXT, -- id de pago de MercadoPago cuando exista la integración real
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_dj_id ON events(dj_id);
CREATE INDEX idx_events_code ON events(code);
CREATE INDEX idx_requests_event_id ON song_requests(event_id);
CREATE INDEX idx_requests_status ON song_requests(event_id, status);
