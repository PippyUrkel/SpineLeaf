import 'package:flutter/material.dart';

/// Generates a visually appealing book cover using the book's metadata
class BookCoverWidget extends StatelessWidget {
  final String title;
  final String author;
  final String bookId;
  final double? width;
  final double? height;

  const BookCoverWidget({
    super.key,
    required this.title,
    required this.author,
    required this.bookId,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final coverColors = _getCoverColors(bookId);

    return Container(
      width: width,
      height: height ?? (width != null ? width! / 0.67 : null),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: coverColors,
        ),
        boxShadow: [
          BoxShadow(
            color: coverColors.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative pattern
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Spine line
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Decorative line
                Container(
                  width: 24,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const Spacer(flex: 1),
                // Title
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width != null && width! < 80 ? 10 : 13,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: width != null && width! < 80 ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Author
                Text(
                  author,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: width != null && width! < 80 ? 8 : 10,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(flex: 2),
                // Bottom decorative element
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
