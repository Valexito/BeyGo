import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/auth/providers/auth_providers.dart'
    show signOutAndNavigateToAuth;
import 'package:beygo/features/reservations/reservations.dart';

class OwnerSettingsPage extends ConsumerStatefulWidget {
  const OwnerSettingsPage({super.key});

  @override
  ConsumerState<OwnerSettingsPage> createState() => _OwnerSettingsPageState();
}

class _OwnerSettingsPageState extends ConsumerState<OwnerSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final notificationAsync = ref.watch(
      ownerNotificationSettingsStreamProvider,
    );
    final parkingAsync = ref.watch(ownerParkingDocumentProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: OwnerOnly(
        builder: (_) {
          final notificationData = notificationAsync.asData?.value;
          final notifyNewReservation =
              (notificationData?['enabled'] as bool?) ??
              preferences.notificationsEnabled;
          final notifyExitRequest =
              (notificationData?['exitRequests'] as bool?) ?? true;
          final notifyCancellation =
              (notificationData?['cancellations'] as bool?) ?? true;

          final parking = parkingAsync.asData?.value;
          final autoApproveReservations =
              parking?.autoApproveReservations ?? false;
          final requirePlateOnEntry = parking?.requirePlateOnEntry ?? true;
          final ownerRevenueVisible = preferences.ownerRevenueVisible;
          final ownerRevenuePin = preferences.ownerRevenuePin;

          return Column(
            children: [
              const AppHeader(
                title: 'Configuración',
                subtitle: 'Preferencias y cuenta',
                showBack: true,
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  children: [
                    // ── Notifications ──────────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notificaciones',
                      subtitle: 'Controla qué alertas recibes',
                    ),
                    _SettingsCard(
                      children: [
                        _SwitchRow(
                          icon: Icons.add_circle_outline_rounded,
                          iconColor: const Color(0xFF2563EB),
                          label: 'Nueva reservación',
                          sublabel: 'Al recibir una solicitud de reserva',
                          value: notifyNewReservation,
                          onChanged:
                              uid == null
                                  ? null
                                  : (v) async {
                                    await ref
                                        .read(appPreferencesProvider.notifier)
                                        .setNotificationsEnabled(v);
                                    await _saveOwnerNotification(uid, {
                                      'enabled': v,
                                    });
                                  },
                        ),
                        _Divider(),
                        _SwitchRow(
                          icon: Icons.exit_to_app_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          label: 'Solicitud de salida',
                          sublabel: 'Cuando un usuario pide salir',
                          value: notifyExitRequest,
                          onChanged:
                              uid == null
                                  ? null
                                  : (v) => _saveOwnerNotification(uid, {
                                    'exitRequests': v,
                                  }),
                        ),
                        _Divider(),
                        _SwitchRow(
                          icon: Icons.cancel_outlined,
                          iconColor: const Color(0xFFF59E0B),
                          label: 'Cancelación',
                          sublabel: 'Solicitudes de cancelación de reservas',
                          value: notifyCancellation,
                          onChanged:
                              uid == null
                                  ? null
                                  : (v) => _saveOwnerNotification(uid, {
                                    'cancellations': v,
                                  }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Parking behavior ───────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.local_parking_rounded,
                      title: 'Comportamiento del parqueo',
                      subtitle: 'Ajusta cómo gestionas tus espacios',
                    ),
                    _SettingsCard(
                      children: [
                        _SwitchRow(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF16A34A),
                          label: 'Auto-aprobar reservaciones',
                          sublabel:
                              'Aprueba automáticamente sin revisión manual',
                          value: autoApproveReservations,
                          onChanged:
                              parking == null
                                  ? null
                                  : (v) => _saveParkingBehavior(parking.id, {
                                    'autoApproveReservations': v,
                                  }),
                          badge: autoApproveReservations ? 'ACTIVO' : null,
                          badgeColor: const Color(0xFF16A34A),
                        ),
                        _Divider(),
                        _SwitchRow(
                          icon: Icons.directions_car_outlined,
                          iconColor: context.appBrandIconColor,
                          label: 'Requerir placa al ingresar',
                          sublabel:
                              'Valida la placa antes de activar la reserva',
                          value: requirePlateOnEntry,
                          onChanged:
                              parking == null
                                  ? null
                                  : (v) => _saveParkingBehavior(parking.id, {
                                    'requirePlateOnEntry': v,
                                  }),
                        ),
                        _Divider(),
                        _SwitchRow(
                          icon: Icons.attach_money_rounded,
                          iconColor: const Color(0xFF16A34A),
                          label: 'Mostrar ingresos en inicio',
                          sublabel:
                              'Muestra o oculta el bloque financiero del dashboard',
                          value: ownerRevenueVisible,
                          onChanged: (v) => _handleRevenueVisibilityChange(v),
                          badge: ownerRevenuePin != null ? 'PIN' : null,
                          badgeColor: const Color(0xFF16A34A),
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.pin_outlined,
                          iconColor: const Color(0xFF16A34A),
                          label:
                              ownerRevenuePin == null
                                  ? 'Crear PIN de ingresos'
                                  : 'Cambiar PIN de ingresos',
                          subtitle:
                              ownerRevenuePin == null
                                  ? 'Protege la activación del bloque financiero'
                                  : 'Actualiza el PIN que protege este módulo',
                          onTap: _handleRevenuePinManagement,
                        ),
                        if (ownerRevenuePin != null) ...[
                          _Divider(),
                          _NavRow(
                            icon: Icons.lock_reset_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            label: 'Olvidé mi PIN',
                            subtitle:
                                'Restablece el PIN confirmando tu identidad',
                            onTap: _handleForgotRevenuePin,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),

                    _SectionHeader(
                      icon: Icons.manage_accounts_rounded,
                      title: 'Cuenta y parqueo',
                      subtitle:
                          'Administra tu perfil y la información publicada',
                    ),
                    _SettingsCard(
                      children: [
                        _NavRow(
                          icon: Icons.person_outline_rounded,
                          iconColor: context.appBrandIconColor,
                          label: 'Editar perfil',
                          subtitle: 'Datos de cuenta y contacto del proveedor',
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditOwnerProfilePage(),
                                ),
                              ),
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.storefront_outlined,
                          iconColor: const Color(0xFF16A34A),
                          label: 'Editar parqueo',
                          subtitle: 'Horarios, fotos, tarifa y datos públicos',
                          onTap:
                              parking == null
                                  ? () => _toast(
                                    'Aún no hay un parqueo publicado para editar.',
                                  )
                                  : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const EditOwnerParkingPage(),
                                    ),
                                  ),
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.delete_outline_rounded,
                          iconColor: const Color(0xFFDC2626),
                          label: 'Solicitar eliminación del parqueo',
                          subtitle:
                              'Disponible fuera del horario publicado y sin reservas activas',
                          onTap:
                              parking == null
                                  ? () => _toast(
                                    'Aún no hay un parqueo publicado para eliminar.',
                                  )
                                  : () => _showDeleteParkingDialog(parking),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── App ───────────────────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.phone_iphone_rounded,
                      title: 'Aplicación',
                    ),
                    _SettingsCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                          child: _ThemeActionItem(
                            icon: Icons.palette_outlined,
                            title: 'Tema',
                            subtitle: _themeLabel(preferences.themePreference),
                            onTap: _showThemePicker,
                          ),
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.share_outlined,
                          iconColor: context.appBrandIconColor,
                          label: 'Compartir app',
                          subtitle: 'Copia un mensaje para recomendar la app',
                          onTap: _shareApp,
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.info_outline_rounded,
                          iconColor: context.appBrandIconColor,
                          label: 'Versión de la app',
                          trailing: const Text(
                            'v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Legal ─────────────────────────────────────────────────
                    _SectionHeader(icon: Icons.gavel_rounded, title: 'Legal'),
                    _SettingsCard(
                      children: [
                        _NavRow(
                          icon: Icons.lock_outline_rounded,
                          iconColor: context.appBrandIconColor,
                          label: 'Política de privacidad',
                          onTap: () => _openLegal('Privacidad'),
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.description_outlined,
                          iconColor: context.appBrandIconColor,
                          label: 'Términos y condiciones',
                          onTap: () => _openLegal('Términos de servicio'),
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.cookie_outlined,
                          iconColor: context.appBrandIconColor,
                          label: 'Política de cookies',
                          onTap: () => _openLegal('Política de cookies'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Support ───────────────────────────────────────────────
                    _SectionHeader(
                      icon: Icons.support_agent_rounded,
                      title: 'Soporte',
                    ),
                    _SettingsCard(
                      children: [
                        _NavRow(
                          icon: Icons.email_outlined,
                          iconColor: context.appBrandIconColor,
                          label: 'Contactar soporte',
                          subtitle: 'Envía un reporte al equipo de soporte',
                          onTap: () => _openSupport(),
                        ),
                        _Divider(),
                        _NavRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: context.appBrandIconColor,
                          label: 'Enviar feedback',
                          subtitle: 'Cuéntanos cómo mejorar la app',
                          onTap: () => _openFeedback(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Logout ────────────────────────────────────────────────
                    _LogoutButton(onTap: () => _logout(context)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: ctx.appCardBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: ctx.isDarkMode ? 0.28 : 0.12,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFFDC2626,
                          ).withValues(alpha: 0.20),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFDC2626),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: ctx.appTextPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¿Seguro que deseas cerrar sesión?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: ctx.appTextSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: ctx.appBorderColor,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: ctx.appCardBackground,
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ctx.appTextPrimaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Salir',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    if (confirmed != true) return;
    await signOutAndNavigateToAuth(context);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _shareApp() async {
    const message =
        'Te recomiendo BeyGo para encontrar, reservar y administrar parqueos de forma rápida.';
    await Clipboard.setData(const ClipboardData(text: message));
    if (!mounted) return;
    _toast('Mensaje copiado para compartir.');
  }

  void _openLegal(String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalInformationPage(initialSection: section),
      ),
    );
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => const ReportProblemPage(
              initialReportType: 'Problema con mi parqueo',
              initialSubject: 'Soporte de proveedor',
            ),
      ),
    );
  }

  void _openFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => const ReportProblemPage(
              initialReportType: 'Otro',
              initialSubject: 'Feedback de la app',
            ),
      ),
    );
  }

  Future<void> _saveOwnerNotification(
    String uid,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref.read(ownerNotificationsSettingsProvider).call(uid, changes);
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo guardar la preferencia: $e');
    }
  }

  Future<void> _saveParkingBehavior(
    String parkingId,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref.read(ownerParkingBehaviorProvider).call(parkingId, changes);
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo guardar la configuración: $e');
    }
  }

  Future<void> _showThemePicker() async {
    final current = ref.read(appPreferencesProvider).themePreference;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.appCardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Selecciona un tema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimaryColor,
                ),
              ),
              const SizedBox(height: 14),
              ...AppThemePreference.values.map((option) {
                final selected = option == current;
                return ListTile(
                  tileColor:
                      selected
                          ? AppColors.headerBottom.withValues(
                            alpha: context.isDarkMode ? 0.16 : 0.08,
                          )
                          : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (option) {
                      AppThemePreference.system =>
                        Icons.brightness_auto_rounded,
                      AppThemePreference.light => Icons.light_mode_rounded,
                      AppThemePreference.dark => Icons.dark_mode_rounded,
                    },
                    color:
                        selected
                            ? context.appBrandIconColor
                            : context.appTextPrimaryColor,
                  ),
                  title: Text(
                    _themeLabel(option),
                    style: TextStyle(color: context.appTextPrimaryColor),
                  ),
                  trailing:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.headerBottom,
                          )
                          : null,
                  onTap: () async {
                    await ref
                        .read(appPreferencesProvider.notifier)
                        .setThemePreference(option);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRevenueVisibilityChange(bool enabled) async {
    final notifier = ref.read(appPreferencesProvider.notifier);
    final preferences = ref.read(appPreferencesProvider);

    if (!enabled) {
      await notifier.setOwnerRevenueVisible(false);
      if (!mounted) return;
      _toast('Ingresos ocultos del inicio.');
      return;
    }

    if (preferences.ownerRevenuePin == null) {
      final pin = await _showRevenuePinSetupDialog();
      if (pin == null) return;
      await notifier.setOwnerRevenuePin(pin);
      await notifier.setOwnerRevenueVisible(true);
      if (!mounted) return;
      _toast('PIN creado e ingresos habilitados.');
      return;
    }

    final valid = await _showRevenuePinVerifyDialog(
      expectedPin: preferences.ownerRevenuePin!,
      title: 'Confirmar PIN',
      subtitle: 'Ingresa tu PIN para mostrar los ingresos en el inicio.',
    );

    if (valid != true) return;
    await notifier.setOwnerRevenueVisible(true);
    if (!mounted) return;
    _toast('Ingresos habilitados.');
  }

  Future<void> _handleRevenuePinManagement() async {
    final notifier = ref.read(appPreferencesProvider.notifier);
    final preferences = ref.read(appPreferencesProvider);

    if (preferences.ownerRevenuePin == null) {
      final pin = await _showRevenuePinSetupDialog();
      if (pin == null) return;
      await notifier.setOwnerRevenuePin(pin);
      if (!mounted) return;
      _toast('PIN creado correctamente.');
      return;
    }

    final valid = await _showRevenuePinVerifyDialog(
      expectedPin: preferences.ownerRevenuePin!,
      title: 'Verificar PIN actual',
      subtitle: 'Ingresa tu PIN actual para poder cambiarlo.',
    );

    if (valid != true) return;

    final newPin = await _showRevenuePinSetupDialog(isChanging: true);
    if (newPin == null) return;

    await notifier.setOwnerRevenuePin(newPin);
    if (!mounted) return;
    _toast('PIN actualizado.');
  }

  Future<void> _handleForgotRevenuePin() async {
    final preferences = ref.read(appPreferencesProvider);
    if (preferences.ownerRevenuePin == null) {
      _toast('Aún no has configurado un PIN.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ctx.appCardBackground,
            title: Text(
              'Restablecer PIN',
              style: TextStyle(color: ctx.appTextPrimaryColor),
            ),
            content: Text(
              'Para restablecer tu PIN de ingresos, primero confirmaremos tu identidad.',
              style: TextStyle(color: ctx.appTextSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    String? emailMasked;
    try {
      final result =
          await FirebaseFunctions.instance
              .httpsCallable('requestOwnerRevenuePinOtp')
              .call();
      final data = Map<String, dynamic>.from(result.data as Map);
      emailMasked = data['emailMasked'] as String?;
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _toast(_mapOtpError(e));
      return;
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo enviar el OTP: $e');
      return;
    }

    if (!mounted) return;

    final resetToken = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _RevenueOtpDialog(
            emailMasked: emailMasked ?? 'tu correo',
            onResend: () async {
              await FirebaseFunctions.instance
                  .httpsCallable('requestOwnerRevenuePinOtp')
                  .call();
            },
            onVerify: (code) async {
              final result = await FirebaseFunctions.instance
                  .httpsCallable('verifyOwnerRevenuePinOtp')
                  .call({'code': code});
              final data = Map<String, dynamic>.from(result.data as Map);
              return data['resetToken'] as String?;
            },
            mapError: _mapOtpError,
          ),
    );

    if (resetToken == null || resetToken.isEmpty) return;

    final newPin = await _showRevenuePinSetupDialog(isChanging: true);
    if (newPin == null) return;

    await ref.read(appPreferencesProvider.notifier).setOwnerRevenuePin(newPin);
    await ref
        .read(appPreferencesProvider.notifier)
        .setOwnerRevenueVisible(false);
    if (!mounted) return;
    _toast('PIN restablecido. Los ingresos quedaron ocultos por seguridad.');
  }

  Future<String?> _showRevenuePinSetupDialog({bool isChanging = false}) async {
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => _RevenuePinDialog(
            title: isChanging ? 'Cambiar PIN' : 'Crear PIN',
            subtitle:
                isChanging
                    ? 'Define un nuevo PIN de 4 dígitos para proteger el bloque de ingresos.'
                    : 'Crea un PIN de 4 dígitos para proteger la activación del bloque de ingresos.',
            confirmLabel: isChanging ? 'Guardar PIN' : 'Crear PIN',
            requireConfirmation: true,
          ),
    );
  }

  Future<bool?> _showRevenuePinVerifyDialog({
    required String expectedPin,
    required String title,
    required String subtitle,
  }) async {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => _RevenuePinDialog(
            title: title,
            subtitle: subtitle,
            confirmLabel: 'Confirmar',
            expectedPin: expectedPin,
            requireConfirmation: false,
          ),
    );
  }

  String _mapOtpError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Tu sesión expiró. Inicia sesión nuevamente.';
        case 'permission-denied':
          return 'No se pudo validar el código ingresado.';
        case 'failed-precondition':
          return error.message ?? 'Primero solicita un nuevo código OTP.';
        case 'deadline-exceeded':
          return 'El código OTP ya venció. Solicita uno nuevo.';
        case 'resource-exhausted':
          return 'Demasiados intentos. Solicita un nuevo código.';
        case 'invalid-argument':
          return 'Ingresa un código válido de 6 dígitos.';
        default:
          return error.message ?? 'No se pudo procesar el OTP.';
      }
    }
    return 'No se pudo procesar el OTP.';
  }

  Future<void> _showDeleteParkingDialog(OwnerParkingDocument parking) async {
    final reservations = await ref.read(ownerAllReservationsProvider.future);
    final hasBlockingReservations = reservations.any(
      (r) => r.state == 'active' || r.state == 'pending',
    );

    if (hasBlockingReservations) {
      _toast(
        'No puedes solicitar eliminación mientras existan reservaciones activas o pendientes.',
      );
      return;
    }

    if (_isWithinBusinessHours(parking.businessHours)) {
      _toast(
        'Esta solicitud solo puede enviarse fuera del horario publicado del parqueo.',
      );
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteParkingRequestDialog(),
    );

    if (reason == null) return;
    if (reason.trim().isEmpty) {
      _toast('Necesitas indicar el motivo de la solicitud.');
      return;
    }

    try {
      await ref
          .read(submitParkingDeletionRequestProvider)
          .call(parking: parking, reason: reason.trim());
      if (!mounted) return;
      _toast('Solicitud enviada. El equipo revisará tu caso.');
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo enviar la solicitud: $e');
    }
  }

  bool _isWithinBusinessHours(Map<String, String> hours) {
    TimeOfDay? parse(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final parts = raw.split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final open = parse(hours['open']);
    final close = parse(hours['close']);
    if (open == null || close == null) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (openMinutes <= closeMinutes) {
      return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
    }
    return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
  }

  String _themeLabel(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.system:
        return 'Predeterminado del sistema';
      case AppThemePreference.light:
        return 'Claro';
      case AppThemePreference.dark:
        return 'Oscuro';
    }
  }
}

// ─── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.headerBottom.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: context.appBrandIconColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimaryColor,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondaryColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Settings card container ───────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.18 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ─── Divider ───────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.appBorderColor,
      indent: 56,
    );
  }
}

// ─── Switch row ────────────────────────────────────────────────────────────────
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? badge;
  final Color? badgeColor;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sublabel,
    required this.value,
    required this.onChanged,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimaryColor,
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor!.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                  ],
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextSecondaryColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Transform.scale(
              scale: 0.92,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.headerBottom,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav row ───────────────────────────────────────────────────────────────────
class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimaryColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appTextSecondaryColor,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Logout button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:
              context.isDarkMode
                  ? const Color(0xFF2A1620)
                  : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.25),
            width: 1.4,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            SizedBox(width: 10),
            Text(
              'Cerrar sesión',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeActionItem extends StatelessWidget {
  const _ThemeActionItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardBackgroundSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appIconCircleColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.8,
                        color: context.appTextPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.appTextSecondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.appTextSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteParkingRequestDialog extends StatefulWidget {
  const _DeleteParkingRequestDialog();

  @override
  State<_DeleteParkingRequestDialog> createState() =>
      _DeleteParkingRequestDialogState();
}

class _DeleteParkingRequestDialogState
    extends State<_DeleteParkingRequestDialog> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appCardBackground,
      title: Text(
        'Solicitar eliminación',
        style: TextStyle(color: context.appTextPrimaryColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tu solicitud quedará pendiente de revisión del equipo. Indica el motivo para continuar.',
            style: TextStyle(color: context.appTextSecondaryColor),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonCtrl,
            maxLines: 4,
            autofocus: true,
            style: TextStyle(color: context.appTextPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Ej: cerraré operaciones definitivamente',
              hintStyle: TextStyle(color: context.appTextSecondaryColor),
              filled: true,
              fillColor: context.appInputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.appBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.appBorderColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: AppColors.headerBottom),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _reasonCtrl.text),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

class _RevenuePinDialog extends StatefulWidget {
  const _RevenuePinDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    this.expectedPin,
    required this.requireConfirmation,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final String? expectedPin;
  final bool requireConfirmation;

  @override
  State<_RevenuePinDialog> createState() => _RevenuePinDialogState();
}

class _RevenuePinDialogState extends State<_RevenuePinDialog> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinCtrl.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'Ingresa un PIN numérico de 4 dígitos.');
      return;
    }

    if (widget.requireConfirmation) {
      if (_confirmCtrl.text.trim() != pin) {
        setState(() => _error = 'La confirmación no coincide.');
        return;
      }
      Navigator.pop(context, pin);
      return;
    }

    if (widget.expectedPin != pin) {
      setState(() => _error = 'PIN incorrecto.');
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final titleIcon =
        widget.requireConfirmation
            ? Icons.lock_outline_rounded
            : Icons.verified_user_outlined;
    final screenHeight = MediaQuery.of(context).size.height;

    InputDecoration pinDecoration(String hint) => InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: TextStyle(color: context.appTextSecondaryColor),
      prefixIcon: Icon(
        Icons.pin_outlined,
        size: 18,
        color: context.appTextSecondaryColor,
      ),
      filled: true,
      fillColor: context.appInputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: context.appBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: context.appBorderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: AppColors.headerBottom, width: 1.5),
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.82),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: context.appCardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.appBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDarkMode ? 0.28 : 0.10,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.headerBottom.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.headerBottom.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        titleIcon,
                        color: context.appBrandIconColor,
                        size: 27,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appTextPrimaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appTextSecondaryColor,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction:
                        widget.requireConfirmation
                            ? TextInputAction.next
                            : TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: true,
                    maxLength: 4,
                    scrollPadding: const EdgeInsets.only(bottom: 140),
                    style: TextStyle(color: context.appTextPrimaryColor),
                    decoration: pinDecoration('PIN de 4 dígitos'),
                  ),
                  if (widget.requireConfirmation) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      obscureText: true,
                      maxLength: 4,
                      scrollPadding: const EdgeInsets.only(bottom: 140),
                      style: TextStyle(color: context.appTextPrimaryColor),
                      decoration: pinDecoration('Confirmar PIN'),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(color: context.appBorderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.headerBottom,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: FittedBox(child: Text(widget.confirmLabel)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevenueOtpDialog extends StatefulWidget {
  const _RevenueOtpDialog({
    required this.emailMasked,
    required this.onResend,
    required this.onVerify,
    required this.mapError,
  });

  final String emailMasked;
  final Future<void> Function() onResend;
  final Future<String?> Function(String code) onVerify;
  final String Function(Object error) mapError;

  @override
  State<_RevenueOtpDialog> createState() => _RevenueOtpDialogState();
}

class _RevenueOtpDialogState extends State<_RevenueOtpDialog> {
  final _codeCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _error = 'Ingresa un código de 6 dígitos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await widget.onVerify(code);
      if (!mounted) return;
      Navigator.pop(context, token);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = widget.mapError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await widget.onResend();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP reenviado al correo.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = widget.mapError(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.84),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: context.appCardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.appBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDarkMode ? 0.28 : 0.10,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.headerBottom.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.headerBottom.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        color: context.appBrandIconColor,
                        size: 27,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verificar OTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appTextPrimaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te enviamos un código al correo registrado del proveedor para restablecer el PIN de ingresos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appTextSecondaryColor,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.appCardBackgroundSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.appBorderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.headerBottom.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.alternate_email_rounded,
                            color: AppColors.headerBottom,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.emailMasked,
                            style: TextStyle(
                              color: context.appTextPrimaryColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    maxLength: 6,
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                    style: TextStyle(color: context.appTextPrimaryColor),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Código OTP',
                      hintStyle: TextStyle(color: context.appTextSecondaryColor),
                      prefixIcon: Icon(
                        Icons.password_rounded,
                        size: 18,
                        color: context.appTextSecondaryColor,
                      ),
                      filled: true,
                      fillColor: context.appInputBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: context.appBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: context.appBorderColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        borderSide: BorderSide(
                          color: AppColors.headerBottom,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _loading ? null : _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _loading || _resending ? null : _resend,
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color:
                            _loading || _resending
                                ? context.appTextSecondaryColor
                                : AppColors.headerBottom,
                      ),
                      label: Text(
                        _resending ? 'Reenviando código...' : 'Reenviar código',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color:
                              _loading || _resending
                                  ? context.appTextSecondaryColor
                                  : AppColors.headerBottom,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _loading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(color: context.appBorderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: AppColors.headerBottom,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            _loading ? 'Verificando...' : 'Verificar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
