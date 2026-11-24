// Punto de entrada de DESARROLLO (proyecto Firebase beygo-development).
//   flutter run --flavor dev -t lib/main_dev.dart
import 'app_environment.dart';
import 'firebase_options_dev.dart';
import 'main.dart' as app;

Future<void> main() => app.bootstrap(
  firebaseOptions: () => DefaultFirebaseOptions.currentPlatform,
  environment: AppEnvironment.dev,
);
