/// Ambiente en el que corre la app. Lo fija el punto de entrada:
/// `lib/main_dev.dart` (dev) o `lib/main_prod.dart` / `lib/main.dart` (prod).
enum AppEnvironment { dev, prod }

class AppEnv {
  AppEnv._();

  static AppEnvironment current = AppEnvironment.prod;

  static bool get isDev => current == AppEnvironment.dev;
  static bool get isProd => current == AppEnvironment.prod;
}
