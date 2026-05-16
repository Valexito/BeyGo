import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/users/users.dart' as userv;
import 'package:beygo/features/reservations/reservations.dart';
import 'firebase_options.dart';
import 'package:beygo/features/auth/auth.dart';
import 'package:beygo/features/owner/owner.dart';

final ValueNotifier<String?> appStartupWarning = ValueNotifier<String?>(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // In debug/emulator we skip App Check so auth/profile validation flows
  // don't get blocked by local attestation noise during development.
  if (!kDebugMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (error, stack) {
      appStartupWarning.value =
          'No se pudo validar la seguridad del dispositivo. Algunas funciones pueden no estar disponibles.';
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'Firebase App Check initialization failed during startup',
      );
    }
  }

  await AppPreferencesService.instance.init();

  // Init FCM (registers background handler + local notifications channel).
  // Token saving happens in NotificationService via its own auth listener.
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);

    return MaterialApp(
      navigatorKey: AppNavigator.key,
      title: 'BeyGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLight(),
      darkTheme: AppTheme.buildDark(),
      themeMode: preferences.themeMode,
      builder: (context, child) => Stack(
        children: [
          SafeArea(child: child!),
          ValueListenableBuilder<String?>(
            valueListenable: appStartupWarning,
            builder: (context, warning, _) {
              if (warning == null) return const SizedBox.shrink();
              return SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Text(
                      warning,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      home: const LaunchSplashPage(),
      routes: {
        '/auth': (_) => const AuthGate(),
        '/home': (_) => const HomeSwitch(),
        '/homePage': (_) => const userv.HomePage(),
        '/owner': (_) => const OwnerHomePage(),
        '/becomeProvider': (_) => const BecomeOwnerPage(),
        '/mapPicker': (_) => const MapPickerPage(),
        '/routeView': (_) => const RouteViewPage(),
        '/reservationsPage': (_) => const ReservationsPage(),
      },
    );
  }
}
