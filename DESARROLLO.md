# Ambiente de desarrollo (DEV) y producción (PROD)

BeyGo tiene dos ambientes que comparten el mismo código:

| | DEV | PROD |
|---|---|---|
| Rama de git | `develop` y ramas `feature/...` o `fix/...` | `main` |
| Proyecto Firebase | `beygo-development` | `beygo-app-prod` |
| App Android | `com.beygo.app.dev` ("BeyGo DEV", con cinta naranja "DEV") | `com.beygo.app` ("BeyGo") |
| Punto de entrada | `lib/main_dev.dart` | `lib/main_prod.dart` (o `lib/main.dart`) |
| Configuración Firebase | `lib/firebase_options_dev.dart` + `android/app/src/dev/google-services.json` | `lib/firebase_options.dart` + `android/app/google-services.json` |
| Funciones (`functions/`) | `.env.beygo-development` (`APP_ENV=dev`: tickets de Jira con "[DEV]"; depuración en simulación) | `.env.beygo-app-prod` |

Las dos apps se pueden instalar a la vez en el mismo teléfono o emulador.

---

## Configuración inicial (una sola vez)

### 1. Ramas de git

```bash
git switch main
git add -A && git commit -m "Ambientes dev/prod (flavors)"   # si hay cambios pendientes
git switch -c develop
git push -u origin develop
```

### 2. Proyecto Firebase de desarrollo

1. Proyecto **BeyGo Development** (ID `beygo-development`). Si algún día lo reemplazas, cambia el ID en `.firebaserc`, en este archivo y en el nombre de `functions/.env.<ID>`.
2. Activa los mismos servicios que en producción:
   - **Authentication**: correo/contraseña y Google.
   - **Firestore** (ubicación `nam5`, igual que producción).
   - **Storage**.
   - **Plan Blaze**, solo si vas a probar Cloud Functions (con poco uso cuesta casi $0; pon una alerta de presupuesto de $1).
3. Registra la app Android y genera la configuración (en la raíz de `BeyGo`):

```bash
flutterfire configure --project=beygo-development --platforms=android \
  --android-package-name=com.beygo.app.dev \
  --out=lib/firebase_options_dev.dart \
  --android-out=android/app/src/dev/google-services.json
```

Esto reemplaza el marcador temporal `lib/firebase_options_dev.dart`.

4. **Inicio de sesión con Google en DEV:** agrega la huella SHA-1 de depuración a la app `com.beygo.app.dev` en la consola de Firebase (Configuración del proyecto → Tus apps). Para obtenerla:

```bash
cd android && ./gradlew signingReport   # usa el SHA1 de la variante devDebug
```

Después descarga otra vez el `google-services.json` (o vuelve a correr el `flutterfire configure` del paso 3).

### 3. Google Maps en DEV

Elige una de estas dos opciones:

- **Misma clave:** en Google Cloud Console → APIs y servicios → Credenciales, edita la clave de Maps y agrega la app `com.beygo.app.dev` con su SHA-1.
- **Clave aparte:** crea una clave en el proyecto `beygo-development` y agrégala a `android/local.properties`:

```properties
MAPS_API_KEY_DEV=tu_clave_de_desarrollo
```

Si `MAPS_API_KEY_DEV` no existe, DEV usa `MAPS_API_KEY`.

### 4. App Check en DEV

En modo debug la app usa el proveedor de depuración. La primera vez que corras la app, busca en el log una línea como `Enter this debug secret into the allow list`. Copia ese token en la consola de `beygo-development` → App Check → la app → Administrar tokens de depuración.

### 5. Backend de DEV (reglas, índices y funciones)

```bash
firebase use dev

# Copia los secretos de producción a DEV sin mostrarlos en pantalla
# (Jira usa el mismo service desk; los tickets de DEV llevan "[DEV]" y la etiqueta "ambiente-dev").
for s in JIRA_EMAIL JIRA_API_TOKEN OWNER_SECURITY_EMAIL OWNER_SECURITY_EMAIL_PASSWORD GOOGLE_ROUTES_API_KEY; do
  firebase functions:secrets:access $s --project beygo-app-prod > /tmp/s.txt
  firebase functions:secrets:set $s --data-file /tmp/s.txt --project beygo-development
done
rm /tmp/s.txt

firebase deploy --only firestore,storage,functions

firebase use prod   # vuelve a producción al terminar
```

Para tener un usuario administrador en DEV, usa `functions/scripts/set_admin_claim.js` contra `beygo-development`.

---

## Día a día

### Correr la app

```bash
flutter run --flavor dev  -t lib/main_dev.dart    # desarrollo
flutter run --flavor prod -t lib/main_prod.dart   # producción
```

En VS Code también puedes elegir **"BeyGo DEV"** o **"BeyGo PROD"** en Run and Debug.

> Con los flavors, `flutter run` y `flutter build` **necesitan** `--flavor`.

### Flujo de trabajo

1. Crea una rama desde `develop`: `git switch develop && git switch -c feature/nuevo-registro`.
2. Desarrolla y prueba con **BeyGo DEV**.
3. Únela a `develop` y vuelve a probar en DEV.
4. Cuando esté lista para usuarios reales, únela a `main` y publica en PROD.

### Desplegar backend

Revisa siempre a qué proyecto apuntas antes de desplegar:

```bash
firebase use            # muestra el proyecto activo
firebase use dev        # o: firebase use prod
firebase deploy --only functions:nombreDeLaFuncion
```

### Publicar en producción

```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart
# o con Shorebird:
shorebird release android --flavor prod --target lib/main_prod.dart --flutter-version=3.29.3
```

> **Shorebird:** las versiones publicadas **antes** de los flavors se compilaron sin `--flavor`. Para la siguiente versión de producción haz un `shorebird release` nuevo con `--flavor prod` (subiendo el número de versión en `pubspec.yaml`); a partir de ahí, los parches usan el mismo flavor:
> `shorebird patch android --flavor prod --target lib/main_prod.dart --release-version=<versión>`.

### Versiones de prueba para otras personas

- **Firebase App Distribution** (proyecto `beygo-development`): `flutter build apk --flavor dev -t lib/main_dev.dart` y sube el APK desde la consola.
- O la **prueba interna** de Google Play, si registras `com.beygo.app.dev` como otra app.

---

## iOS

El proyecto de Xcode ya tiene los dos ambientes:

| | DEV | PROD |
|---|---|---|
| Esquema de Xcode | `dev` | `prod` |
| Configuraciones | `Debug-dev`, `Release-dev`, `Profile-dev` | `Debug-prod`, `Release-prod`, `Profile-prod` (y `Debug`/`Release`/`Profile`) |
| Bundle ID | `com.beygo.app.dev` ("BeyGo DEV") | `com.beygo.app` ("BeyGo") |
| Configuración Firebase | `ios/config/dev/GoogleService-Info.plist` | `ios/config/prod/GoogleService-Info.plist` |

Una fase de compilación ("Copy GoogleService-Info.plist") copia el archivo del ambiente dentro de la app y registra su `REVERSED_CLIENT_ID` como URL scheme para el inicio con Google. En iOS, Firebase se inicializa desde ese archivo (no desde `firebase_options*.dart`).

### Configuración inicial (una sola vez)

> **Cuenta gratuita de Apple:** se puede instalar la app DEV en tu propio iPhone con Xcode (Personal Team), sin pagar. Limitaciones: la instalación caduca a los 7 días (vuelves a correr `flutter run`), no hay notificaciones push ni "Iniciar sesión con Apple" (por eso `Runner.entitlements` está vacío) y no se puede usar TestFlight ni App Store. Los pasos 2 (APNs) y TestFlight requieren el Apple Developer Program ($99/año).
>
> **Estado actual:** iOS se prueba solo en **DEV**. Mientras no exista `ios/config/prod/GoogleService-Info.plist`, cualquier compilación iOS de producción se detiene con un error claro; los pasos de `beygo-app-prod` quedan para cuando se publique en App Store.

1. **Apps iOS en Firebase.** En cada proyecto: Configuración del proyecto → Agregar app → iOS.
   - `beygo-development`: bundle ID `com.beygo.app.dev` → descarga `GoogleService-Info.plist` a `ios/config/dev/`.
   - `beygo-app-prod`: bundle ID `com.beygo.app` → descarga `GoogleService-Info.plist` a `ios/config/prod/`.
   - Hazlo con Google ya habilitado en Authentication, para que el archivo traiga `CLIENT_ID` y `REVERSED_CLIENT_ID`.
2. **Notificaciones push (APNs).** En https://developer.apple.com/account → Certificates, IDs & Profiles → Keys → crea una clave con **Apple Push Notifications service (APNs)** y descarga el `.p8` (solo se puede descargar una vez). Súbela en Firebase → Configuración del proyecto → Cloud Messaging → app iOS → Clave de autenticación de APNs, **en los dos proyectos**, con tu Key ID y Team ID.
3. **Google Maps.** En Google Cloud Console crea (o reutiliza) una clave restringida a **apps iOS** con los bundle IDs `com.beygo.app` y `com.beygo.app.dev`, con Maps SDK for iOS habilitado. Luego:

```bash
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
# edita ios/Flutter/Secrets.xcconfig y pon MAPS_API_KEY_IOS = tu_clave
```

4. **Firma en Xcode.** `open ios/Runner.xcworkspace` → target **Runner** → Signing & Capabilities → marca *Automatically manage signing* y elige tu **Team** (aplica a todas las configuraciones). Con cuenta gratuita aparece como "Tu Nombre (Personal Team)"; Xcode registra el bundle ID solo. Push Notifications y Sign in with Apple se agregan cuando haya Apple Developer Program.
5. **Dependencias.**

```bash
flutter pub get
cd ios && pod install && cd ..
```

### Correr en iPhone o simulador

```bash
flutter run --flavor dev  -t lib/main_dev.dart    # BeyGo DEV
flutter run --flavor prod -t lib/main_prod.dart   # BeyGo
```

Para un iPhone físico, conéctalo, confía en la Mac y activa el **Modo desarrollador** (Ajustes → Privacidad y seguridad). Las notificaciones push no llegan al simulador.

### TestFlight

```bash
flutter build ipa --flavor prod -t lib/main_prod.dart
```

Sube el `.ipa` con la app **Transporter** o desde Xcode (Organizer). Para probar DEV en TestFlight, crea en App Store Connect una app aparte con el bundle ID `com.beygo.app.dev`.

### Pendiente para publicar en App Store

- **Iniciar sesión con Apple:** Apple lo exige si la app ofrece inicio con Google. La capacidad ya está en `Runner.entitlements`; falta habilitar el proveedor Apple en Firebase Authentication y agregar el botón en la app.
- **Crashlytics en iOS:** agregar el script de subida de dSYM para ver los errores simbolizados.
