import 'package:flutter/material.dart';

/// A fun, lightweight, Material 3 compliant "Soda Can / Liquid Level" progress indicator.
/// Fills from bottom to top like liquid in a soda can with subtle fizz bubbles.
class SodaProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double width;
  final double height;
  final Color? color;
  final bool showPercentText;

  const SodaProgressIndicator({
    super.key,
    required this.progress,
    this.width = 24.0,
    this.height = 56.0,
    this.color,
    this.showPercentText = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedProgress = progress.clamp(0.0, 1.0);
    final liquidColor = color ?? theme.colorScheme.primary;

    return Semantics(
      label: 'Reading progress: ${(clampedProgress * 100).round()}%',
      value: '${(clampedProgress * 100).round()}%',
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Can container
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(width * 0.4),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
                width: 1.5,
              ),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Top cap rim detail
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 3,
                  child: Container(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),

                // Liquid fill from bottom
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: clampedProgress,
                    widthFactor: 1.0,
                    child: CustomPainterWidget(
                      color: liquidColor,
                      progress: clampedProgress,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Optional percent label
          if (showPercentText && width >= 36)
            Text(
              '${(clampedProgress * 100).round()}%',
              style: TextStyle(
                fontSize: width * 0.28,
                fontWeight: FontWeight.bold,
                color: clampedProgress > 0.5 ? Colors.white : theme.colorScheme.onSurface,
                shadows: const [
                  Shadow(color: Colors.black38, blurRadius: 2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Lightweight CustomPainter for liquid level & subtle fizz dots.
class CustomPainterWidget extends StatelessWidget {
  final Color color;
  final double progress;

  const CustomPainterWidget({
    super.key,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LiquidPainter(color: color, progress: progress),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final Color color;
  final double progress;

  _LiquidPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.85),
            color,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Fill body
    final path = Path();
    path.moveTo(0, 4);

    // Mild liquid curve at top
    final waveHeight = size.height > 10 ? 3.0 : 1.0;
    path.quadraticBezierTo(
      size.width * 0.5,
      -waveHeight,
      size.width,
      4,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw 2-3 tiny soda fizz bubbles if progress > 0.1
    if (progress > 0.1 && size.height > 12) {
      final bubblePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 1.2, bubblePaint);
      canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.7), 1.5, bubblePaint);
      if (size.height > 24) {
        canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.25), 1.0, bubblePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
