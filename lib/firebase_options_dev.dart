// MARCADOR TEMPORAL: este archivo se reemplaza al configurar el proyecto
// Firebase de desarrollo (ver DESARROLLO.md, paso 2):
//
//   flutterfire configure --project=beygo-app-dev --platforms=android \
//     --android-package-name=com.beygo.app.dev \
//     --out=lib/firebase_options_dev.dart \
//     --android-out=android/app/src/dev/google-services.json
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Falta configurar Firebase DEV: corre flutterfire configure (ver DESARROLLO.md).',
  );
}
