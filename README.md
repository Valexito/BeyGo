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

## Deploy y separación de proyectos

- Este proyecto `BeyGo` usa el proyecto Firebase `beygo-app-prod` para app y backend.
- La web pública y Firebase Hosting se administran desde el proyecto separado `beygo-site`.
- No hagas deploy de hosting desde `BeyGo`.

Flujo recomendado:

- Backend/app desde `BeyGo`: `firebase deploy --only functions,firestore,storage`
- Web pública desde `beygo-site`: `npm run deploy:hosting`
