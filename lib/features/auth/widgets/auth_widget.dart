// auth_widgets.dart
// Shared widgets used by both login_screen.dart and register_screen.dart.
// Public (no underscore) so they can be imported freely.

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';

// ─── Google Sign-In Button ────────────────────────────────────────────────────
class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const GoogleSignInButton({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E2030) : Colors.white,
          side: BorderSide(
            color: isDark ? Colors.white24 : const Color(0xFFDADCE0),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogoIcon(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF3C4043),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Google "G" Logo ─────────────────────────────────────────────────────────
class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(22, 22),
        painter: _GoogleLogoPainter(),
      );
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // White background
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width:  size.width,
      height: size.height,
    );

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect.deflate(2),
        start,
        sweep,
        false,
        Paint()
          ..color      = color
          ..style      = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.18
          ..strokeCap  = StrokeCap.butt,
      );
    }

    const pi = 3.14159265;
    arc(const Color(0xFF4285F4), -0.25 * pi, 0.5 * pi); // blue  (right)
    arc(const Color(0xFFEA4335),  0.75 * pi, 0.5 * pi); // red   (top)
    arc(const Color(0xFFFBBC05),  1.25 * pi, 0.5 * pi); // yellow(left)
    arc(const Color(0xFF34A853),  1.75 * pi, 0.5 * pi); // green (bottom)

    // Blue crossbar
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.55, cy),
      Paint()
        ..color      = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.18
        ..strokeCap  = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Error Banner ─────────────────────────────────────────────────────────────
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
        ]),
      );
}