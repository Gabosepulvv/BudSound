/// Client ID tipo "Web" del proyecto de Google Cloud Console — el idToken
/// que genera el SDK de Google en el celular va dirigido a esta audiencia,
/// y es el mismo valor que el backend usa para verificarlo
/// (`GOOGLE_CLIENT_ID` en su `.env`). No es el Client ID "Android" (ese se
/// registra en Google Cloud junto al SHA-1 del APK, pero nunca se escribe
/// acá en el código).
///
/// Se pasa en build/run time para no dejarlo hardcodeado en el repo:
/// `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxxx.apps.googleusercontent.com`
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static bool get configurado => serverClientId.isNotEmpty;
}
