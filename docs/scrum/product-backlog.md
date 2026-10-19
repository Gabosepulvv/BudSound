# Product Backlog priorizado — BudSound

Historias de usuario agrupadas por épica, con prioridad (Alta/Media/Baja)
y estado real al cierre del proyecto. El estado refleja lo que está
efectivamente implementado y funcionando hoy en el repositorio, no una
proyección.

## Épica: Autenticación

| # | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| HU01 | Como usuario nuevo, quiero registrarme eligiendo un rol (Participante o DJ), para acceder a la interfaz correspondiente. | Alta | Hecho |
| HU02 | Como usuario registrado, quiero iniciar sesión con correo y contraseña, para acceder a mi cuenta. | Alta | Hecho |
| HU03 | Como usuario, quiero iniciar sesión con mi cuenta de Google, para no tener que crear una contraseña nueva. | Media | Hecho |
| HU04 | Como usuario nuevo, quiero verificar mi correo antes de poder usar la cuenta, para confirmar que es realmente mío. | Alta | Hecho |
| HU05 | Como usuario, quiero recuperar mi contraseña si la olvido, para no perder el acceso a mi cuenta. | Media | Hecho |

## Épica: Eventos

| # | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| HU06 | Como DJ, quiero crear un evento y obtener un código QR, para que el público pueda unirse fácilmente. | Alta | Hecho |
| HU07 | Como DJ, quiero tener un solo evento activo a la vez, para que no se confundan las solicitudes entre dos eventos. | Alta | Hecho |
| HU08 | Como Participante, quiero escanear el QR del evento, para unirme sin escribir ningún código. | Alta | Hecho |
| HU09 | Como Participante, quiero poder ingresar el código del evento a mano, para unirme si no puedo escanear el QR. | Baja | Hecho |
| HU10 | Como DJ, quiero cerrar mi evento y ver un resumen de recaudación y solicitudes aceptadas, para saber cómo me fue. | Media | Hecho |

## Épica: Solicitudes de canciones

| # | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| HU11 | Como Participante, quiero buscar una canción por título o artista, para encontrar la que quiero pedir. | Alta | Hecho |
| HU12 | Como Participante, quiero enviar una solicitud con una propina obligatoria, para mostrarle al DJ que realmente me interesa. | Alta | Hecho |
| HU13 | Como DJ, quiero ver las solicitudes en una cola ordenada por orden de llegada, para decidir con criterio artístico, no por quién pagó más. | Alta | Hecho |
| HU14 | Como DJ, quiero tener un plazo definido (7 minutos) para aceptar o rechazar cada solicitud, para que no queden colgadas indefinidamente. | Alta | Hecho |
| HU15 | Como Participante, quiero ver en tiempo real si mi solicitud fue aceptada o rechazada, para no tener que preguntar. | Media | Hecho |
| HU16 | Como DJ, quiero ver el BPM de la canción solicitada, para decidir si calza con el momento del set. | Baja | Hecho |
| HU17 | Como DJ, quiero que no me puedan saturar la cola repitiendo la misma canción, para que la cola siga siendo manejable. | Media | Hecho |

## Épica: Pagos

| # | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| HU18 | Como Participante, quiero que mi propina solo se cobre si el DJ acepta mi solicitud, para no pagar por algo que no pasó. | Alta | Hecho |
| HU19 | Como DJ, quiero conectar mi propia cuenta de MercadoPago, para recibir las propinas directo, sin pasar por un tercero. | Alta | Hecho |
| HU20 | Como responsable de la plataforma, quiero cobrar una comisión automática sobre cada propina aceptada, para sostener el negocio. | Media | Hecho |
| HU21 | Como tester/evaluador, quiero poder probar el flujo completo sin usar dinero real, para que la demo no dependa de tarjetas ni cuentas reales. | Baja | Hecho |

## Épica: Perfil y estadísticas

| # | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| HU22 | Como DJ, quiero ver mis estadísticas y el historial de mis eventos pasados, para hacer seguimiento de mi actividad. | Media | Hecho |
| HU23 | Como usuario, quiero poder activar un modo daltónico, para distinguir bien los estados de la app. | Baja | Hecho |

## Épica: Primer uso

| # | Historia de usuario | Prioridad | Estado |
|---|---|---|---|
| HU24 | Como usuario nuevo, quiero un recorrido rápido de bienvenida, para entender cómo funciona la app sin leer un manual. | Media | Hecho |

## Backlog técnico (no son historias de usuario, pero se priorizaron igual)

| Ítem | Prioridad | Estado |
|---|---|---|
| Auditoría de seguridad (sockets, JWT, errores 500, WebView de pago) | Alta | Hecho |
| Despliegue a producción (Railway) con dominio fijo | Alta | Hecho |
| Dockerizar el backend + base de datos para desarrollo local reproducible | Media | Hecho |
| Pruebas automatizadas (unitarias, integración, rendimiento, seguridad) | Alta | **Pendiente** |
| Diagramas UML formales (casos de uso, clases, secuencia, componentes) | Media | **Pendiente** |
| Verificación formal de la app ante Google (OAuth fuera de modo prueba) | Baja | **Pendiente** |
