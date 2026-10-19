# Diagrama de clases — modelos de dominio (Flutter)

Clases de datos (`lib/models/`) que la app Flutter usa para representar lo
que recibe del backend. No son clases de negocio con lógica propia (eso
vive en los `services/` y en el backend) — son el espejo tipado de las
filas de `schema.sql` en el lado de la app.

```mermaid
classDiagram
    class UserModel {
        +String? id
        +String nombre
        +String apellido
        +String email
        +DateTime fechaNacimiento
        +UserRole rol
        +String? nombreArtistico
        +DateTime? nombreArtisticoCambiadoAt
        +String? avatarDataUrl
    }

    class UserRole {
        <<enumeration>>
        PARTICIPANTE
        DJ
    }

    class EventModel {
        +String id
        +String djId
        +String code
        +String nombre
        +String status
        +DateTime createdAt
        +DateTime? closedAt
        +String? horaInicio
        +String? horaFin
        +DateTime? fechaInicio
        +DateTime? fechaFin
        +List~String~ generos
        +String? imagenDataUrl
        +String? djNombreArtistico
        +fechaVisible() String
    }

    class SongRequestModel {
        +String id
        +String eventId
        +String participanteId
        +int itunesTrackId
        +String titulo
        +String artista
        +String? artworkUrl
        +int montoClp
        +String status
        +int? bpm
        +DateTime createdAt
        +DateTime? resolvedAt
        +DateTime? reproducidaAt
        +String? participanteNombre
        +pendiente() bool
        +aceptada() bool
        +tienePropina() bool
    }

    class TransactionModel {
        +String id
        +String requestId
        +int montoBrutoClp
        +int comisionClp
        +int montoNetoClp
        +String status
    }

    UserModel "1" --> "0..1" UserRole : rol
    UserModel "1" --> "0..*" EventModel : crea (DJ)
    UserModel "1" --> "0..*" SongRequestModel : pide (Participante)
    EventModel "1" --> "0..*" SongRequestModel : recibe
    SongRequestModel "1" --> "0..1" TransactionModel : genera
```
