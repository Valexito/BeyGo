# BeyGo — Checklist para publicar en Play Store

Auditoría hecha sobre el código actual (lib/, android/, functions/, firestore.rules, firebase.json, pubspec.yaml). Lo que aparece marcado como **bloqueante** debe resolverse antes de Production. Internal testing puede empezar con casi todo lo demás.

---

## 0) Resumen ejecutivo

Lo bueno: App Check con Play Integrity está bien configurado, targetSdk 35, ProGuard/R8 activos, keystore via `key.properties`, Firestore rules detalladas con validación por campos, Cloud Functions usan `defineSecret`, account deletion existe, legal info en app.

Lo bloqueante: faltan reglas de Storage, secretos no excluidos en `.gitignore`, `print()` en código de release, App Check no se enforza en Functions callables, no hay prominent disclosure de ubicación, no hay Privacy Policy ni URL de deletion públicas, no hay block/report en chat, account deletion incompleta.

---

## 1) BLOQUEANTES (resolver antes de subir a Production)



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



### 1.9 `applicationId` final: `com.dev.parking`

Este nombre NO se puede cambiar después del primer release a producción. "com.dev.parking" es genérico y no refleja la marca BeyGo.

**Decisión a tomar AHORA:** ¿quedarte con `com.dev.parking` (irreversible) o cambiarlo a algo como `com.beygo.app` o `gt.beygo.app` (si tu empresa registró un dominio)? El paquete `change_app_package_name` ya lo tienes en pubspec, solo corres `dart run change_app_package_name:main com.beygo.app` y commit. Esto también afecta SHA fingerprints — toca regenerar Google Sign-In, App Check y Maps API restriction.

---

## 2) RECOMENDADOS (no bloquean, pero deberías tenerlos)
flutter analyze
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info


### 2.3 Restringir Maps API key

`AIzaSyC7FJXBLr_cVkfx_nXXR80zBtk7JUFzBS0` puede ser extraído del APK. En Google Cloud Console → APIs & Services → Credentials, restringe la key a:
- Application: Android apps
- Package name: el final (com.dev.parking o com.beygo.app)
- SHA-1: el de tu keystore de upload Y el de Play App Signing (después de subir el primer AAB)

Sin restricciones, cualquiera puede usarla y te puede generar cargos.


### 2.6 Pre-launch report

Cuando subas el AAB a Internal testing, Play Console corre automáticamente tu app en ~10 dispositivos reales y te da un report de crashes, screenshots, performance, accesibilidad. Revísalo antes de avanzar a Closed testing.

### 2.7 Cuenta de developer nueva: 14 días + 12 testers

Si tu cuenta de Google Play Developer la creaste después de noviembre 2023 como personal, tienes que hacer 14+ días de Closed testing con 12+ testers reales antes de poder pasar a Production. Empieza Internal testing YA para tener tiempo.





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

