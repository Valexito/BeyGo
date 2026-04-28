# BeyGo

App móvil Flutter para encontrar y reservar parqueos cercanos en tiempo real.

## Stack
- Flutter (Dart 3.7+)
- Google Maps + Places + Directions
- Firebase (Auth, Firestore, Storage, Functions, Messaging, App Check)
- Riverpod para state management

## Configuración local

1. Instala dependencias:
   ```bash
   flutter pub get
   ```

2. Configura tus API keys (no se commitean):
   - `android/local.properties` debe contener `MAPS_API_KEY=<tu_key>`
   - opcional en debug: `.vscode/launch.json` puede pasar `--dart-define=GOOGLE_MAPS_KEY=<tu_key>`
   - en Android, Places y Maps ahora pueden reutilizar la misma key del `AndroidManifest`

3. Corre la app:
   ```bash
   flutter run
   ```

## Build de release

Ver instrucciones en `android/key.properties.template`.
