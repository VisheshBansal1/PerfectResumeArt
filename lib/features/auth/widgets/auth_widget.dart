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
                      color: isDark ? Colors.white : const Color(0xFF3C4043),
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
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(22, 22), painter: _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // White background
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);

    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size.width,
      height: size.height,
    );

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect.deflate(2),
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.18
          ..strokeCap = StrokeCap.butt,
      );
    }

    const pi = 3.14159265;
    arc(const Color(0xFF4285F4), -0.25 * pi, 0.5 * pi); // blue  (right)
    arc(const Color(0xFFEA4335), 0.75 * pi, 0.5 * pi); // red   (top)
    arc(const Color(0xFFFBBC05), 1.25 * pi, 0.5 * pi); // yellow(left)
    arc(const Color(0xFF34A853), 1.75 * pi, 0.5 * pi); // green (bottom)

    // Blue crossbar
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.55, cy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.18
        ..strokeCap = StrokeCap.round,
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
    child: Row(
      children: [
        Icon(Icons.error_outline, color: AppTheme.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: AppTheme.error, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

// ─── Brand Lockup (logo + wordmark) ───────────────────────────────────────────
// Used in both the compact mobile header and the wide-screen brand panel so
// the two stay visually identical. "Art" always carries a small hand-drawn
// accent stroke underneath it — the one signature flourish tying the mark
// back to the brand name, kept quiet everywhere else.
class BrandLockup extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  // true = render for display on the colored gradient panel (white text,
  // translucent logo backing). false = render on a plain surface, adapting
  // automatically to light/dark theme.
  final bool onColor;

  const BrandLockup({
    super.key,
    this.logoSize = 52,
    this.fontSize = 21,
    this.onColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wordColor = onColor
        ? Colors.white
        : (isDark ? Colors.white : AppTheme.textPrimary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: EdgeInsets.all(logoSize * 0.14),
          decoration: BoxDecoration(
            color: onColor
                ? Colors.white.withOpacity(0.14)
                : (isDark ? AppTheme.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(logoSize * 0.3),
            border: Border.all(
              color: onColor
                  ? Colors.white.withOpacity(0.22)
                  : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
            ),
            boxShadow: onColor
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Image.asset(
            'assets/logo/image.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.auto_awesome_rounded,
              color: onColor ? Colors.white : AppTheme.primary,
              size: logoSize * 0.46,
            ),
          ),
        ),
        SizedBox(width: logoSize * 0.32),
        Flexible(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                'Perfect Resume ',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.05,
                  color: wordColor,
                ),
              ),
              _ArtWord(fontSize: fontSize, color: wordColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtWord extends StatelessWidget {
  final double fontSize;
  final Color color;
  const _ArtWord({required this.fontSize, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'Art',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.05,
            color: color,
          ),
        ),
        Positioned(
          left: 1,
          right: 1,
          bottom: -fontSize * 0.16,
          child: CustomPaint(
            size: Size.fromHeight(fontSize * 0.22),
            painter: _SwoopUnderlinePainter(color: AppTheme.accent),
          ),
        ),
      ],
    );
  }
}

// A single confident, slightly-tapered curve — not a decorative squiggle.
// This is the design's one deliberate flourish, so everywhere else stays quiet.
class _SwoopUnderlinePainter extends CustomPainter {
  final Color color;
  const _SwoopUnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = (size.height * 0.5).clamp(2.0, 4.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 1.6,
        size.width,
        size.height * 0.5,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SwoopUnderlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─── Wide-screen brand panel ──────────────────────────────────────────────────
// Shown alongside the form on web / tablet-landscape widths. Copy is grounded
// in real features (ATS scoring, AI feedback, interview prep) rather than
// generic marketing filler.
class AuthPanelFeature {
  final IconData icon;
  final String label;
  const AuthPanelFeature(this.icon, this.label);
}

class AuthBrandPanel extends StatelessWidget {
  final String eyebrow;
  final String headline;
  final String subheadline;
  final List<AuthPanelFeature> features;

  const AuthBrandPanel({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.subheadline,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Faint stacked-page motif in the background — a quiet nod to
          // "resume" without illustrating anything literally.
          Positioned(
            right: -70,
            top: 70,
            child: Transform.rotate(
              angle: -0.12,
              child: _pageOutline(220, 280, 0.10),
            ),
          ),
          Positioned(
            right: -30,
            top: 110,
            child: Transform.rotate(
              angle: -0.05,
              child: _pageOutline(220, 280, 0.16),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(48, 64, 48, 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLockup(logoSize: 60, fontSize: 24, onColor: true),
                const SizedBox(height: 52),
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subheadline,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 15.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(f.icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            f.label,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageOutline(double w, double h, double opacity) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white.withOpacity(opacity), width: 1.4),
      borderRadius: BorderRadius.circular(18),
    ),
  );
}
