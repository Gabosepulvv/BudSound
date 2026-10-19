# Diagrama de secuencia — enviar y resolver una solicitud de canción

La funcionalidad principal del sistema: desde que el Participante envía
una solicitud hasta que ve el resultado, pasando por la cola en vivo del
DJ y el cobro condicionado de la propina.

```mermaid
sequenceDiagram
    actor P as Participante
    participant App as App Flutter
    participant BE as Backend (Express)
    participant Deezer
    participant DB as PostgreSQL
    participant Socket as Socket.io
    actor DJ
    participant MP as MercadoPago

    P->>App: Elige canción + monto (propina obligatoria)
    App->>BE: POST /events/:id/requests
    BE->>BE: Valida evento activo, rango de monto,<br/>límite de 7 min por canción
    BE->>Deezer: Consulta BPM (mejor esfuerzo)
    Deezer-->>BE: BPM o null
    BE->>DB: INSERT song_requests (PENDIENTE)

    alt Hay credenciales reales de MercadoPago
        BE->>MP: Autoriza pago (capture:false)
        MP-->>BE: authorized / pending_capture
        BE->>DB: INSERT transactions (AUTORIZADA)
    else Modo demo (sin credenciales)
        Note over BE: Se confirma una propina simulada,<br/>sin tarjeta ni cobro real
    end

    BE-->>App: 201 Created
    BE->>Socket: emit request:created
    Socket-->>DJ: Nueva solicitud en la cola

    DJ->>BE: PATCH /requests/:id/accept (o /reject)
    BE->>DB: UPDATE song_requests.status

    alt Aceptada y con credenciales reales
        BE->>MP: Captura el pago (capture:true)
        MP-->>BE: approved / accredited
        BE->>DB: UPDATE transactions (APROBADA)
    else Rechazada y con credenciales reales
        BE->>MP: Cancela la reserva
        MP-->>BE: cancelled
        BE->>DB: UPDATE transactions (RECHAZADA)
    end

    BE->>Socket: emit request:resolved
    Socket-->>App: Estado actualizado
    App-->>P: Ve si fue aceptada o rechazada, en vivo
```

## Caso alternativo: el DJ no responde a tiempo

```mermaid
sequenceDiagram
    participant Cron as Job de limpieza (cada 1 min)
    participant DB as PostgreSQL
    participant MP as MercadoPago
    participant Socket as Socket.io

    loop Cada CLEANUP_INTERVAL_MINUTES
        Cron->>DB: Busca solicitudes PENDIENTE con<br/>más de 7 min, o de un evento ya CERRADO
        DB-->>Cron: Lista de solicitudes colgadas
        Cron->>DB: UPDATE status = CANCELADA
        opt Tenía una autorización retenida
            Cron->>MP: Cancela la autorización
        end
        Cron->>Socket: emit request:resolved
    end
```
