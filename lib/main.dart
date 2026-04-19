import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:mapbox_api/common/services/notification_service.dart';

import 'package:mapbox_api/features/reservations/pages/route_view_page.dart';
import 'firebase_options.dart';
import 'common/ui/components/app_styles.dart';
import 'features/auth/pages/auth_gate.dart';
import 'features/core/pages/home_switch.dart';
import 'features/core/pages/userv/home_page.dart' as userv;
import 'features/owner/owner_home_page.dart';
import 'features/owner/widgets/become_owner_page.dart';
import 'features/reservations/pages/reservations_page.dart';
import 'common/ui/widgets/map_picker_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

  // Init FCM (background handler, local notifications, channel setup).
  // Token is NOT saved here because the user may not be authenticated yet.
  await NotificationService.instance.init();

  // ✅ THE FIX: save FCM token as soon as auth state is known.
  // This fires immediately on launch if a session already exists,
  // OR after the user logs in for the first time — covering both cases.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      NotificationService.instance.onSignIn();
    }
  });

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa con Parqueos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      builder: (context, child) => SafeArea(child: child!),
      home: const AuthGate(),
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
