import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/users/users.dart' as userv;
import 'package:beygo/features/reservations/reservations.dart';
import 'firebase_options.dart';
import 'package:beygo/features/auth/auth.dart';
import 'package:beygo/features/owner/owner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // In debug/emulator we skip App Check so auth/profile validation flows
  // don't get blocked by local attestation noise during development.
  if (!kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
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
      navigatorKey: NotificationService.navigatorKey,
      title: 'BeyGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLight(),
      darkTheme: AppTheme.buildDark(),
      themeMode: preferences.themeMode,
      builder: (context, child) => SafeArea(child: child!),
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
