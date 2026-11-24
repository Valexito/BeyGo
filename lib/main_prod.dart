// Punto de entrada de PRODUCCIÓN (proyecto Firebase beygo-app-prod).
//   flutter run --flavor prod -t lib/main_prod.dart
import 'app_environment.dart';
import 'firebase_options.dart';
import 'main.dart' as app;

Future<void> main() => app.bootstrap(
  firebaseOptions: () => DefaultFirebaseOptions.currentPlatform,
  environment: AppEnvironment.prod,
);
