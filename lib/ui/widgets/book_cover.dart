import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Renders book covers with cover-based reading progress:
/// The completed portion (bottom) shows in full bright color with a smooth liquid wave crest,
/// while the unread portion (top) is darkened.
class BookCoverWidget extends StatelessWidget {
  final String title;
  final String author;
  final String bookId;
  final String? coverPath;
  final Uint8List? coverImageData;
  final double? width;
  final double? height;
  final double progress; // 0.0 to 1.0

  const BookCoverWidget({
    super.key,
    required this.title,
    required this.author,
    required this.bookId,
    this.coverPath,
    this.coverImageData,
    this.width,
    this.height,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final computedHeight = height ?? (width != null ? width! / 0.67 : null);
    final clampedProgress = progress.clamp(0.0, 1.0);

    Widget baseCover;

    // Type 1: Check if cover image is provided as bytes
    if (coverImageData != null && coverImageData!.isNotEmpty) {
      baseCover = _buildImageCover(Image.memory(coverImageData!, fit: BoxFit.cover), computedHeight);
    } else if (coverPath != null && coverPath!.isNotEmpty && File(coverPath!).existsSync()) {
      // Type 1: Check if cover image file exists
      baseCover = _buildImageCover(Image.file(File(coverPath!), fit: BoxFit.cover), computedHeight);
    } else {
      // Type 2: Default asset PNG cover
      baseCover = _buildDefaultAssetCover(computedHeight);
    }

    // Wrap base cover with cover-based wavy liquid progress overlay
    return Stack(
      children: [
        baseCover,

        // Wavy liquid progress overlay (darkens unread top section)
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _WavyCoverProgressOverlay(progress: clampedProgress),
          ),
        ),
      ],
    );
  }

  /// Builds a Type 1 cover image container with book frame shadows and spine detail.
  Widget _buildImageCover(Widget imageWidget, double? computedHeight) {
    return Container(
      width: width,
      height: computedHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // First page / cover image
          imageWidget,

          // Spine overlay
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Inner frame border
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a Type 2 default cover using pre-rendered PNG cover assets.
  Widget _buildDefaultAssetCover(double? computedHeight) {
    final coverIndex = (bookId.hashCode.abs() % 5) + 1;
    return _buildImageCover(
      Image.asset(
        'assets/covers/cover_$coverIndex.png',
        fit: BoxFit.cover,
      ),
      computedHeight,
    );
  }

  List<Color> _getCoverColors(String bookId) {
    final palettes = [
      [const Color(0xFF1A237E), const Color(0xFF283593)],  // Deep Indigo
      [const Color(0xFF4A148C), const Color(0xFF6A1B9A)],  // Deep Purple
      [const Color(0xFF004D40), const Color(0xFF00695C)],  // Teal
      [const Color(0xFFBF360C), const Color(0xFFD84315)],  // Deep Orange
      [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],  // Green
      [const Color(0xFF880E4F), const Color(0xFFAD1457)],  // Pink
      [const Color(0xFF0D47A1), const Color(0xFF1565C0)],  // Blue
      [const Color(0xFF3E2723), const Color(0xFF4E342E)],  // Brown
      [const Color(0xFF263238), const Color(0xFF37474F)],  // Blue Grey
      [const Color(0xFF311B92), const Color(0xFF4527A0)],  // Deep Purple 2
    ];

    final hash = bookId.codeUnits.fold<int>(0, (a, b) => a + b);
    return palettes[hash % palettes.length];
  }
}

/// Overlay that darkens the unread portion (top) of a cover with a wavy liquid crest line.
class _WavyCoverProgressOverlay extends StatelessWidget {
  final double progress;

  const _WavyCoverProgressOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.0) {
      return Container(color: Colors.black.withValues(alpha: 0.55));
    }
    if (progress >= 1.0) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _CoverWaveDarkenPainter(progress: progress),
    );
  }
}

class _CoverWaveDarkenPainter extends CustomPainter {
  final double progress;

  _CoverWaveDarkenPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final liquidY = size.height * (1.0 - progress);

    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.58)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, liquidY + 2);

    path.quadraticBezierTo(
      size.width * 0.5,
      liquidY - 4,
      0,
      liquidY + 2,
    );
    path.close();

    canvas.drawPath(path, darkPaint);

    final waveLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final linePath = Path();
    linePath.moveTo(0, liquidY + 2);
    linePath.quadraticBezierTo(
      size.width * 0.5,
      liquidY - 4,
      size.width,
      liquidY + 2,
    );

    canvas.drawPath(linePath, waveLinePaint);
  }

  @override
  bool shouldRepaint(covariant _CoverWaveDarkenPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
