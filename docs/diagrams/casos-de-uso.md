# Diagrama de casos de uso — BudSound

Mermaid no tiene un tipo de diagrama UML de casos de uso nativo; se
representa con un flowchart: los actores fuera del recuadro del sistema,
los casos de uso como nodos redondeados dentro de él.

```mermaid
flowchart LR
    Participante(["Participante"])
    DJ(["DJ"])

    subgraph Sistema["Sistema BudSound"]
        direction TB
        CU1(["Registrarse con rol"])
        CU2(["Iniciar sesión<br/>(correo o Google)"])
        CU3(["Verificar correo"])
        CU4(["Recuperar contraseña"])
        CU5(["Crear evento"])
        CU6(["Mostrar código QR"])
        CU7(["Cerrar evento"])
        CU8(["Conectar cuenta<br/>de MercadoPago"])
        CU9(["Escanear QR /<br/>ingresar código"])
        CU10(["Buscar canción"])
        CU11(["Enviar solicitud<br/>con propina"])
        CU12(["Ver estado de<br/>mi solicitud"])
        CU13(["Ver cola de<br/>solicitudes"])
        CU14(["Aceptar solicitud"])
        CU15(["Rechazar solicitud"])
        CU16(["Marcar canción<br/>como reproducida"])
        CU17(["Ver estadísticas<br/>y recaudación"])
    end

    Participante --> CU1
    Participante --> CU2
    Participante --> CU3
    Participante --> CU4
    Participante --> CU9
    Participante --> CU10
    Participante --> CU11
    Participante --> CU12

    DJ --> CU1
    DJ --> CU2
    DJ --> CU3
    DJ --> CU4
    DJ --> CU5
    DJ --> CU6
    DJ --> CU7
    DJ --> CU8
    DJ --> CU13
    DJ --> CU14
    DJ --> CU15
    DJ --> CU16
    DJ --> CU17

    CU5 -.->|incluye| CU6
    CU11 -.->|incluye| CU10
    CU14 -.->|incluye| CU16
    CU7 -.->|incluye| CU17
```

## Descripción breve de los casos de uso principales

| Caso de uso | Actor | Descripción |
|---|---|---|
| Enviar solicitud con propina | Participante | Busca una canción y la envía al DJ con una propina obligatoria ($500–$20.000 CLP). El pago se reserva, no se cobra todavía. |
| Ver cola de solicitudes | DJ | Ve las solicitudes pendientes de su evento activo, en orden de llegada, con un plazo de 7 minutos para responder cada una. |
| Aceptar solicitud | DJ | Marca la solicitud como aceptada; se captura (cobra) la propina reservada. |
| Rechazar solicitud | DJ | Marca la solicitud como rechazada; se libera la propina reservada, sin cobrar nada. |
| Conectar cuenta de MercadoPago | DJ | Autoriza a BudSound (OAuth) para que las propinas de sus eventos se cobren directo en su propia cuenta. |
