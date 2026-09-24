import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// An animated "in progress" visual for checks that take a few seconds
/// (ATS scan, custom tech-stack analysis, deep AI check) — a pulsing radar
/// ring around an icon, with the label cross-fading as the caller's real
/// state changes (e.g. "Reading resume..." -> "Running deep AI check...").
/// Replaces a bare spinner so the wait feels purposeful.
class ScanningOverlay extends StatefulWidget {
  final String label;
  final IconData icon;

  const ScanningOverlay({
    super.key,
    required this.label,
    this.icon = Icons.fact_check_rounded,
  });

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                for (final phase in const [0.0, 0.33, 0.66])
                  _ring((_pulse.value + phase) % 1.0),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            widget.label,
            key: ValueKey(widget.label),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMain(context),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 150,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: AppTheme.primary.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ring(double progress) {
    final scale = 0.4 + progress * 0.65;
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.5;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}