# Ambiente de desarrollo (DEV) y producción (PROD)

BeyGo tiene dos ambientes que comparten el mismo código:

| | DEV | PROD |
|---|---|---|
| Rama de git | `develop` y ramas `feature/...` o `fix/...` | `main` |
| Proyecto Firebase | `beygo-development` | `beygo-app-prod` |
| App Android | `com.beygo.app.dev` ("BeyGo DEV", con cinta naranja "DEV") | `com.beygo.app` ("BeyGo") |
| Punto de entrada | `lib/main_dev.dart` | `lib/main_prod.dart` (o `lib/main.dart`) |
| Configuración Firebase | `lib/firebase_options_dev.dart` + `android/app/src/dev/google-services.json` | `lib/firebase_options.dart` + `android/app/google-services.json` |
| Funciones (`functions/`) | `.env.beygo-development` (Jira apagado, depuración en simulación) | `.env.beygo-app-prod` |

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

# Las funciones declaran estos secretos: en DEV deben existir aunque no se usen.
# Jira está apagado (JIRA_ENABLED=false), así que basta un valor de relleno.
printf '%s' 'no-usar' > /tmp/x.txt
firebase functions:secrets:set JIRA_EMAIL --data-file /tmp/x.txt
firebase functions:secrets:set JIRA_API_TOKEN --data-file /tmp/x.txt
rm /tmp/x.txt
# Correo de envío y Routes API: usa valores reales si quieres probar esas funciones.
firebase functions:secrets:set OWNER_SECURITY_EMAIL
firebase functions:secrets:set OWNER_SECURITY_EMAIL_PASSWORD
firebase functions:secrets:set GOOGLE_ROUTES_API_KEY

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

Pendiente. Requiere la cuenta Apple Developer ($99 al año). Cuando se active: registrar las apps iOS en ambos proyectos de Firebase, configurar los esquemas de Xcode por ambiente y agregar "Iniciar sesión con Apple".
