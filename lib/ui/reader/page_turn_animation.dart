import 'package:flutter/material.dart';

/// A page turn animation widget that provides realistic, dynamic page transitions.
/// Renders both current and target page content simultaneously with 1:1 touch tracking.
class PageTurnWidget extends StatefulWidget {
  final Widget Function(int pageIndex) pageBuilder;
  final int currentPage;
  final int totalPages;
  final void Function(int newPage) onPageChanged;
  final Duration duration;

  const PageTurnWidget({
    super.key,
    required this.pageBuilder,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<PageTurnWidget> createState() => PageTurnWidgetState();
}

class PageTurnWidgetState extends State<PageTurnWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Animation<double>? _offsetAnimation;
  double _dragOffset = 0;
  bool _isDragging = false;
  bool _isAnimating = false;
  int? _targetPage;

  static const _swipeThreshold = 0.20;
  static const _velocityThreshold = 250.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Programmatically turns to the next page with slide animation
  void turnToNext() {
    if (_isAnimating) return;
    final screenWidth = MediaQuery.of(context).size.width;
    _animateToOffset(-screenWidth, widget.currentPage + 1);
  }

  /// Programmatically turns to the previous page with slide animation
  void turnToPrevious() {
    if (_isAnimating) return;
    final screenWidth = MediaQuery.of(context).size.width;
    _animateToOffset(screenWidth, widget.currentPage - 1);
  }

  void _animateToOffset(double targetOffset, int targetPage) {
    _isAnimating = true;
    _targetPage = targetPage;
    final startOffset = _dragOffset;

    _animController.reset();
    _offsetAnimation = Tween<double>(
      begin: startOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    void listener() {
      if (mounted) {
        setState(() {
          _dragOffset = _offsetAnimation!.value;
        });
      }
    }

    _offsetAnimation!.addListener(listener);

    _animController.forward().then((_) {
      _offsetAnimation?.removeListener(listener);
      _isAnimating = false;
      _dragOffset = 0;
      final target = _targetPage;
      _targetPage = null;
      if (target != null && target != widget.currentPage && mounted) {
        widget.onPageChanged(target);
      }
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _isDragging = true;
    _dragOffset = 0;
    _animController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;
    setState(() {
      _dragOffset += details.primaryDelta ?? 0;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging || _isAnimating) return;
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final fraction = _dragOffset / screenWidth;
    final velocity = details.primaryVelocity ?? 0;

    bool shouldTurn = false;
    int direction = 0; // -1 = next (drag left), 1 = previous (drag right)

    if (fraction.abs() > _swipeThreshold || velocity.abs() > _velocityThreshold) {
      if (_dragOffset > 0) {
        shouldTurn = true;
        direction = 1;
      } else if (_dragOffset < 0) {
        shouldTurn = true;
        direction = -1;
      }
    }

    if (shouldTurn) {
      final endOffset = direction * screenWidth;
      _animateToOffset(endOffset, widget.currentPage - direction);
    } else {
      // Snap back if threshold not met
      _animateToOffset(0, widget.currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine target page index for preview
    int? previewPageIndex;
    if (_dragOffset < 0 && widget.currentPage < widget.totalPages - 1) {
      previewPageIndex = widget.currentPage + 1;
    } else if (_dragOffset > 0 && widget.currentPage > 0) {
      previewPageIndex = widget.currentPage - 1;
    }

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: ClipRect(
        child: Stack(
          children: [
            // Current Page (slides with drag)
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: SizedBox(
                width: screenWidth,
                child: widget.pageBuilder(widget.currentPage),
              ),
            ),

            // Incoming Page (slides in tandem with real content)
            if (previewPageIndex != null)
              Transform.translate(
                offset: Offset(
                  _dragOffset < 0 ? (screenWidth + _dragOffset) : (-screenWidth + _dragOffset),
                  0,
                ),
                child: SizedBox(
                  width: screenWidth,
                  child: widget.pageBuilder(previewPageIndex),
                ),
              ),

            // Realistic book fold shadow along sliding boundary
            if (_dragOffset.abs() > 2)
              Positioned(
                left: _dragOffset < 0 ? screenWidth + _dragOffset - 12 : null,
                right: _dragOffset > 0 ? screenWidth - _dragOffset - 12 : null,
                top: 0,
                bottom: 0,
                width: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: _dragOffset < 0 ? Alignment.centerLeft : Alignment.centerRight,
                      end: _dragOffset < 0 ? Alignment.centerRight : Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
