# Modelo de datos (ER) — BudSound

PostgreSQL, modelo relacional. Fuente real:
[`budsound_backend/src/db/schema.sql`](../../budsound_backend/src/db/schema.sql).

```mermaid
erDiagram
    USERS ||--o{ EVENTS : "crea (dj_id)"
    USERS ||--o{ SONG_REQUESTS : "pide (participante_id)"
    EVENTS ||--o{ SONG_REQUESTS : "recibe"
    SONG_REQUESTS ||--o| TRANSACTIONS : "genera"

    USERS {
        uuid id PK
        text email UK
        text password_hash "null si es cuenta de Google"
        user_role role "PARTICIPANTE o DJ"
        text nombre
        text apellido
        text nombre_artistico "solo DJ"
        boolean email_verificado
        bigint mp_collector_id "OAuth MercadoPago del DJ"
        text mp_access_token
        text mp_nickname
        timestamptz created_at
    }

    EVENTS {
        uuid id PK
        uuid dj_id FK
        text code UK "valor codificado en el QR"
        text nombre
        date fecha_inicio
        date fecha_fin
        text generos "arreglo"
        event_status status "ACTIVO o CERRADO"
        timestamptz created_at
        timestamptz closed_at
    }

    SONG_REQUESTS {
        uuid id PK
        uuid event_id FK
        uuid participante_id FK
        bigint itunes_track_id
        text titulo
        text artista
        int monto_clp "propina, 500-20000, obligatoria"
        boolean terminos_aceptados
        int bpm "Deezer, puede ser null"
        request_status status "PENDIENTE/ACEPTADA/RECHAZADA/CANCELADA"
        timestamptz created_at
        timestamptz resolved_at
        timestamptz reproducida_at "evidencia anti-contracargo"
    }

    TRANSACTIONS {
        uuid id PK
        uuid request_id FK, UK "1 a 1 con la solicitud"
        int monto_bruto_clp
        int comision_clp
        int monto_neto_clp
        transaction_status status "PENDIENTE/AUTORIZADA/APROBADA/RECHAZADA"
        text mp_payment_id
        timestamptz created_at
    }
```

## Notas

- `users.role` distingue PARTICIPANTE de DJ dentro de la misma tabla — es
  una sola aplicación con dos roles, no dos esquemas separados.
- `transactions` tiene una relación 1 a 1 (no 1 a N) con `song_requests`:
  una solicitud nunca genera más de una transacción, por eso
  `request_id` es `UNIQUE`.
- Las claves foráneas usan `ON DELETE CASCADE`: borrar un usuario borra
  sus eventos/solicitudes; borrar un evento borra sus solicitudes; borrar
  una solicitud borra su transacción.
