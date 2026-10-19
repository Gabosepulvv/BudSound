# budsound

App móvil (Flutter) para pedir canciones a un DJ en eventos en vivo
mediante un código QR, con una propina opcional al DJ. Una sola base de
código para los dos roles (Participante y DJ) — la interfaz cambia según
el rol de la cuenta.

## Qué hay ahora

- Registro con rol (Participante o DJ), login con correo/contraseña o con
  Google Sign-In, verificación de correo y recuperación de contraseña
  (reales, contra el backend).
- Recorrido de bienvenida la primera vez que se registra una cuenta.
- **Inicio** (solo Participante): acceso directo al evento ya escaneado.
- **En vivo**: el DJ crea el evento y gestiona la cola de solicitudes con
  aceptar/rechazar y un plazo de 7 minutos para responder; el Participante
  escanea el QR o ingresa el código a mano, busca canciones (iTunes
  Search API, solo metadatos — la app nunca reproduce audio) y envía
  solicitudes con una propina obligatoria.
- **Perfil**: datos de sesión, para el DJ sus estadísticas y el historial
  de eventos pasados, y la conexión de su cuenta de MercadoPago.
- Modo daltónico (reemplaza el acento de marca y el color de error por
  azul/naranja) y modo de pago simulado cuando el backend no tiene
  credenciales reales de MercadoPago cargadas.

## Cómo correrla

```bash
flutter pub get
flutter run
```

Por defecto apunta al backend local (`localhost`, o `10.0.2.2` en el
emulador Android). Ver `lib/core/api_config.dart` para apuntar a un
backend desplegado (ej. Railway) en vez de local.
