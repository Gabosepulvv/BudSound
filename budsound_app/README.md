# budsound

App Flutter de descubrimiento de DJs y sesiones en vivo.

## Qué hay ahora

- Splash con restauración de JWT en disco
- Login / registro (Público o DJ) y recuperación de contraseña (auth simulada)
- Google Sign-In simulado
- **Descubrir**: catálogo iTunes Search API con preview de 30 s
- **En vivo**: salas de DJ (catálogo local hasta el backend)
- **Perfil**: datos de sesión y cierre

## Cómo correrla

```bash
flutter pub get
flutter run
```

En web, iTunes puede requerir el proxy CORS ya incluido en `ItunesService`.
