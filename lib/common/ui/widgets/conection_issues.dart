import 'package:flutter/material.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';

class AppNoConnection extends StatefulWidget {
  final VoidCallback? onRetry;
  final String? title;
  final String? message;
  final bool fullScreen;

  const AppNoConnection({
    super.key,
    this.onRetry,
    this.title,
    this.message,
    this.fullScreen = true,
  });

  /// Compact card version — drop inside any Column/ListView
  const AppNoConnection.card({
    super.key,
    this.onRetry,
    this.title,
    this.message,
  }) : fullScreen = false;

  /// Show as a bottom sheet
  static Future<void> sheet(BuildContext context, {VoidCallback? onRetry}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _NoConnectionSheet(onRetry: onRetry),
    );
  }

  /// Show as a snackbar (lightweight)
  static void snack(BuildContext context, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Sin conexión a internet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  State<AppNoConnection> createState() => _AppNoConnectionState();
}

class _AppNoConnectionState extends State<AppNoConnection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _bounce = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.fullScreen) return _buildCard();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.headerTop.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.headerBottom.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildContent(compact: true),
    );
  }

  Widget _buildContent({bool compact = false}) {
    final title = widget.title ?? '¡Oops! Sin conexión';
    final message =
        widget.message ?? 'Revisa tu conexión a internet e inténtalo de nuevo.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Animated wifi icon
          AnimatedBuilder(
            animation: _ctrl,
            builder:
                (_, __) => Transform.translate(
                  offset: Offset(0, _bounce.value),
                  child: Container(
                    width: compact ? 64 : 90,
                    height: compact ? 64 : 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.headerBottom.withOpacity(
                            0.10 + 0.08 * _fade.value,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: compact ? 30 : 42,
                      color: AppColors.headerBottom.withOpacity(0.7),
                    ),
                  ),
                ),
          ),

          SizedBox(height: compact ? 16 : 24),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A94A6),
              height: 1.5,
            ),
          ),

          SizedBox(height: compact ? 20 : 32),

          if (widget.onRetry != null)
            MyButton(
              text: 'Reintentar',
              icon: Icons.refresh_rounded,
              onTap: widget.onRetry,
              margin: EdgeInsets.zero,
              height: 50,
            ),

          if (!compact) ...[
            const SizedBox(height: 14),
            Text(
              'Si el problema persiste, inténtalo más tarde.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bottom sheet variant ─────────────────────────────────────────────────────
class _NoConnectionSheet extends StatelessWidget {
  final VoidCallback? onRetry;
  const _NoConnectionSheet({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.headerBottom.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 30,
              color: AppColors.headerBottom,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Oops! Sin conexión',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revisa tu conexión a internet e inténtalo de nuevo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.headerBottom.withOpacity(0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cerrar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.headerBottom,
                      ),
                    ),
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: MyButton(
                    text: 'Reintentar',
                    height: 48,
                    onTap: () {
                      Navigator.pop(context);
                      onRetry!();
                    },
                    margin: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
