# BeyGo — Checklist para publicar en Play Store

Auditoría hecha sobre el código actual (lib/, android/, functions/, firestore.rules, firebase.json, pubspec.yaml). Lo que aparece marcado como **bloqueante** debe resolverse antes de Production. Internal testing puede empezar con casi todo lo demás.

---

## 0) Resumen ejecutivo

Lo bueno: App Check con Play Integrity está bien configurado, targetSdk 35, ProGuard/R8 activos, keystore via `key.properties`, Firestore rules detalladas con validación por campos, Cloud Functions usan `defineSecret`, account deletion existe, legal info en app.

Lo bloqueante: faltan reglas de Storage, secretos no excluidos en `.gitignore`, `print()` en código de release, App Check no se enforza en Functions callables, no hay prominent disclosure de ubicación, no hay Privacy Policy ni URL de deletion públicas, no hay block/report en chat, account deletion incompleta.

---

## 1) BLOQUEANTES (resolver antes de subir a Production)


Luego: `firebase deploy --only storage`.

### 1.2 `.gitignore` no excluye secretos

`local.properties` contiene `MAPS_API_KEY=AIza…`, `key.properties` contendrá los passwords del keystore, `google-services.json` tiene el Firebase API key. Ninguno está en `.gitignore`.

**Acción:** agregar al `.gitignore`:

```
android/local.properties
android/key.properties
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
env_dev.json
*.jks
*.keystore
```

Luego verificar que no estén ya commiteados en el historial:
`git log --all --full-history -- android/local.properties android/key.properties android/app/google-services.json`

Si aparecen en el historial: rotar las claves (Maps API key en GCP Console; google-services.json se regenera desde Firebase Console).

### 1.3 `print()` en código de release

En release builds, `print()` SÍ se imprime y queda en logcat. Solo `debugPrint` es no-op en release. Archivos afectados:

- `lib/features/owner/providers/provider_request_submit_provider.dart` — printa uid, paths, bytes (líneas 53–187)
- `lib/features/reservations/providers/parking_service_provider.dart` — printa uid+path+size en upload (317, 325)

**Acción:** reemplazar todos los `print(...)` por `debugPrint(...)`, o envolver en `if (kDebugMode) { ... }`.

### 1.4 App Check no se enforza en Cloud Functions callables

En `functions/index.js`, las funciones `onCall` (`requestOwnerRevenuePinOtp`, `verifyOwnerRevenuePinOtp`, `ownerForceFinalizeReservation`, `sendOwnerHistoryReport`) NO especifican `enforceAppCheck: true`. Significa que un atacante con un token de Auth válido (robado o comprado) puede invocarlas desde curl.

**Acción:** en cada `onCall`, agregar la opción:

```js
exports.requestOwnerRevenuePinOtp = onCall({
  enforceAppCheck: true,
  secrets: [ownerSecurityEmail, ownerSecurityEmailPassword],
}, async (request) => { ... });
```

Aplicar a las 4 callable functions.

### 1.5 Prominent disclosure de location ausente

`lib/common/services/geolocator.dart` llama `Geolocator.requestPermission()` directo. Google requiere que ANTES del system prompt aparezca un diálogo propio explicando: qué datos toma, para qué se usa, si se comparten. Esto es causa común de rechazo en Play Console.

**Acción:** antes de la primera llamada a `Geolocator.requestPermission()`, mostrar un `AlertDialog` propio con texto tipo:

> "BeyGo usa tu ubicación para mostrarte parqueos cercanos y trazar rutas hacia ellos. Solo se usa mientras tienes la app abierta y nunca se comparte con terceros. ¿Continuar?"

Solo si el usuario acepta, llamas a `Geolocator.requestPermission()`.

### 1.6 Privacy Policy URL pública

Play Console exige una URL https pública de Privacy Policy. El contenido actual vive solo en `legal_information_page.dart` dentro de la app.

**Acción:** hostear el texto (puedes copiarlo de `legal_information_page.dart` y expandirlo con: qué datos exactos recolectas — email, nombre, teléfono, ubicación, fotos de perfil, placas, historial; con qué terceros se comparten — Firebase, Google Maps, FCM, Gmail SMTP; cómo se borran; contacto). Opciones gratis: GitHub Pages, Notion público, página estática en Firebase Hosting (ya tienes el proyecto).

### 1.7 Account deletion: URL pública + completitud

Google exige (a) borrado in-app, (b) URL pública donde un usuario que YA desinstaló pueda pedir borrado. Y el borrado debe ser completo.

**a) URL pública:** una página `/delete-account` en el mismo dominio de Privacy Policy con instrucciones o un form que cree un ticket de soporte.

**b) Limpieza incompleta:** `lib/features/users/providers/delete_account_provider.dart` solo borra `favorites`, `users/{uid}/settings`, `users/{uid}` doc y el Auth user. NO borra:
- `users/{uid}/vehicles/*`
- `users/{uid}/reservation_control/main`
- Reservaciones pasadas (donde `userId == uid`)
- Provider applications y provider requests (`uid == uid`)
- Foto de perfil en Storage
- FCM token (al borrar el doc users/{uid} sí se va, pero confirmar)
- Reviews que el usuario haya dejado en `parkings/{id}/reviews/*`

**Acción recomendada:** mover el delete a un Cloud Function callable con `enforceAppCheck: true` que use admin SDK para cleanup completo. El cliente solo llama la function y luego cierra sesión.

### 1.8 No hay block/report en chat 1-a-1

El chat de reservación (`reservation_chat_sheet.dart`) no tiene mecanismo de:
- Reportar un mensaje específico
- Reportar/bloquear al otro participante
- Que admin pueda borrar mensajes

Google UGC policy lo exige. Sin esto, riesgo alto de rechazo o suspensión post-lanzamiento.

**Acción:** agregar long-press en cada mensaje → "Reportar mensaje" que cree un doc en `support_reports` con `reportType: 'chat_message'`, `reservationId`, `messageId`, `reportedUid`. Permitir bloquear al participante (afecta solo notificaciones y nuevos mensajes, no cancela la reserva en curso).

### 1.9 `applicationId` final: `com.dev.parking`

Este nombre NO se puede cambiar después del primer release a producción. "com.dev.parking" es genérico y no refleja la marca BeyGo.

**Decisión a tomar AHORA:** ¿quedarte con `com.dev.parking` (irreversible) o cambiarlo a algo como `com.beygo.app` o `gt.beygo.app` (si tu empresa registró un dominio)? El paquete `change_app_package_name` ya lo tienes en pubspec, solo corres `dart run change_app_package_name:main com.beygo.app` y commit. Esto también afecta SHA fingerprints — toca regenerar Google Sign-In, App Check y Maps API restriction.

---

## 2) RECOMENDADOS (no bloquean, pero deberías tenerlos)

### 2.1 Crashlytics

No está en pubspec ni en build.gradle. Sin Crashlytics no vas a poder ver crashes post-lanzamiento.

Agregar: `firebase_crashlytics: ^4.x` en pubspec, `implementation("com.google.firebase:firebase-crashlytics")` en build.gradle, y wrap del main:

```dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

Y subir los debug symbols del `--obfuscate` build a Crashlytics para que los stack traces se desofusquen.

### 2.2 Fallback de signing config peligroso

En `android/app/build.gradle.kts` líneas 76–81:

```kotlin
signingConfig = if (rootProject.file("key.properties").exists()) {
  signingConfigs.getByName("release")
} else {
  signingConfigs.getByName("debug")
}
```

Si en CI o un build accidental falta `key.properties`, produce un AAB firmado con la debug key — Play Store lo rechaza pero peor, podría confundir tu pipeline. Recomendación: lanzar `error("key.properties missing")` en release.

### 2.3 Restringir Maps API key

`AIzaSyC7FJXBLr_cVkfx_nXXR80zBtk7JUFzBS0` puede ser extraído del APK. En Google Cloud Console → APIs & Services → Credentials, restringe la key a:
- Application: Android apps
- Package name: el final (com.dev.parking o com.beygo.app)
- SHA-1: el de tu keystore de upload Y el de Play App Signing (después de subir el primer AAB)

Sin restricciones, cualquiera puede usarla y te puede generar cargos.

### 2.4 Admin en Firestore rules

Hardcodeado:
```
request.auth.token.email in ["alexarpe.15@gmail.com"]
```

Más robusto: usar custom claims. Cloud Function que setee `admin: true` con `admin.auth().setCustomUserClaims(uid, {admin: true})` y rule `request.auth.token.admin == true`.

### 2.5 Try/catch alrededor de App Check init

Si Play Integrity falla (dispositivo sin Play Services certificados), `FirebaseAppCheck.instance.activate(...)` lanza excepción y revienta el main. Envolver en try/catch para que la app arranque aunque App Check falle (los servicios se verán bloqueados por enforcement, pero al menos el usuario ve un mensaje en pantalla en vez de un boot loop).

### 2.6 Pre-launch report

Cuando subas el AAB a Internal testing, Play Console corre automáticamente tu app en ~10 dispositivos reales y te da un report de crashes, screenshots, performance, accesibilidad. Revísalo antes de avanzar a Closed testing.

### 2.7 Cuenta de developer nueva: 14 días + 12 testers

Si tu cuenta de Google Play Developer la creaste después de noviembre 2023 como personal, tienes que hacer 14+ días de Closed testing con 12+ testers reales antes de poder pasar a Production. Empieza Internal testing YA para tener tiempo.

### 2.8 Considera firebase_secure_storage

Si guardas tokens propios (no de Firebase, eso lo maneja el SDK), úsalo en lugar de SharedPreferences.

---

## 3) Lo que ya está bien hecho

- App Check con Play Integrity (release) y App Attest (iOS), auto-refresh on. `main.dart` 26–30.
- targetSdk = 35, compileSdk = 35, minSdk = 23 — cumple las exigencias 2025–2026.
- Manifest: solo permisos necesarios, sin `ACCESS_BACKGROUND_LOCATION`.
- Signing config externa via `key.properties` (template provisto).
- ProGuard/R8 enabled con reglas amplias.
- Firestore rules: validación de campos, hasOnly en diff de updates, separación user/owner/admin, transacciones para state changes.
- Cloud Functions: `defineSecret` para credenciales SMTP, OTP hasheado con SHA-256, transacciones para cancelación, schedule mensual para reportes.
- Account deletion existe (aunque incompleta — ver 1.7).
- Legal info accesible en app.
- FCM con auth state listener y retry para guardar token.
- Versionado del buildNumber documentado en pubspec.

---

## 4) Comando de build de release

Una vez resuelto lo bloqueante:

```bash
flutter clean
flutter pub get
cd functions && npm install && cd ..

# Verifica reglas en emulator antes de deployar
firebase emulators:start --only firestore,storage

# Deploy backend
firebase deploy --only firestore:rules,storage,functions

# Build AAB de release con ofuscación + symbol map para Crashlytics
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=./debug-symbols/$(date +%Y%m%d-%H%M%S) \
  --dart-define=GOOGLE_MAPS_KEY=$MAPS_API_KEY
```

El `.aab` queda en `build/app/outputs/bundle/release/app-release.aab`. Súbelo a Internal testing primero.

---

## 5) Orden sugerido de trabajo

1. Corregir `.gitignore` y rotar secrets si ya están commiteados (15 min).
2. Crear `storage.rules` y deployar (20 min).
3. Cambiar `print()` por `debugPrint` (15 min).
4. Agregar `enforceAppCheck: true` en las 4 callables y redeploy (10 min).
5. Decidir `applicationId` definitivo y, si cambia, correr `change_app_package_name` (30 min).
6. Implementar prominent disclosure de location (1 hora).
7. Migrar account deletion a Cloud Function callable con cleanup completo (2–3 horas).
8. Implementar report/block en chat (2–4 horas).
9. Hostear Privacy Policy + Account Deletion URL públicas (1–2 horas).
10. Agregar Crashlytics (1 hora).
11. Restringir Maps API key en GCP (10 min).
12. Build release + Internal testing (30 min).
13. Llenar Data Safety, Content Rating, Target Audience, Permission Declaration en Play Console (1–2 horas).
14. Closed testing 14 días con 12 testers.
15. Production.

Total estimado del trabajo de código: ~10–15 horas. Más las 2 semanas de Closed testing si tu cuenta es nueva.
