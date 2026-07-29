import 'package:flutter/material.dart';

/// A page turn animation widget that provides smooth horizontal page transitions.
/// Wraps content and handles swipe gestures for page navigation.
class PageTurnWidget extends StatefulWidget {
  /// Builder for the page content at the given index.
  final Widget Function(int pageIndex) pageBuilder;

  /// Current page index.
  final int currentPage;

  /// Total number of pages.
  final int totalPages;

  /// Called when the user navigates to a new page.
  final void Function(int newPage) onPageChanged;

  /// Animation duration.
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
  State<PageTurnWidget> createState() => _PageTurnWidgetState();
}

class _PageTurnWidgetState extends State<PageTurnWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _dragOffset = 0;
  bool _isDragging = false;

  // Threshold for completing a page turn (fraction of screen width)
  static const _swipeThreshold = 0.25;
  // Minimum velocity to trigger a page turn
  static const _velocityThreshold = 300.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(PageTurnWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragOffset = 0;
    _animController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset += details.primaryDelta ?? 0;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final fraction = _dragOffset / screenWidth;
    final velocity = details.primaryVelocity ?? 0;

    bool shouldTurn = false;
    int direction = 0; // -1 = next, 1 = previous

    if (fraction.abs() > _swipeThreshold || velocity.abs() > _velocityThreshold) {
      if (_dragOffset > 0 && widget.currentPage > 0) {
        // Swiped right -> previous page
        shouldTurn = true;
        direction = 1;
      } else if (_dragOffset < 0 && widget.currentPage < widget.totalPages - 1) {
        // Swiped left -> next page
        shouldTurn = true;
        direction = -1;
      }
    }

    if (shouldTurn) {
      final newPage = widget.currentPage - direction;

      // Animate to completion
      final startOffset = _dragOffset;
      final endOffset = direction * screenWidth;

      _animController.reset();
      _animController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _dragOffset = 0;
          widget.onPageChanged(newPage);
        }
      });

      final animation = Tween<double>(
        begin: startOffset,
        end: endOffset,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ));

      animation.addListener(() {
        _dragOffset = animation.value;
      });

      _animController.forward();
    } else {
      // Snap back
      final startOffset = _dragOffset;
      _animController.reset();

      final animation = Tween<double>(
        begin: startOffset,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ));

      animation.addListener(() {
        _dragOffset = animation.value;
      });

      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: ClipRect(
        child: Stack(
          children: [
            // Current page
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: SizedBox(
                width: screenWidth,
                child: widget.pageBuilder(widget.currentPage),
              ),
            ),

            // Next/previous page (sliding in)
            if (_dragOffset < 0 && widget.currentPage < widget.totalPages - 1)
              Transform.translate(
                offset: Offset(screenWidth + _dragOffset, 0),
                child: SizedBox(
                  width: screenWidth,
                  child: widget.pageBuilder(widget.currentPage + 1),
                ),
              ),

            if (_dragOffset > 0 && widget.currentPage > 0)
              Transform.translate(
                offset: Offset(-screenWidth + _dragOffset, 0),
                child: SizedBox(
                  width: screenWidth,
                  child: widget.pageBuilder(widget.currentPage - 1),
                ),
              ),

            // Subtle shadow on page edge during drag
            if (_dragOffset.abs() > 1)
              Positioned(
                left: _dragOffset < 0 ? null : _dragOffset - 8,
                right: _dragOffset > 0 ? null : -_dragOffset - 8,
                top: 0,
                bottom: 0,
                width: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: _dragOffset < 0 ? Alignment.centerLeft : Alignment.centerRight,
                      end: _dragOffset < 0 ? Alignment.centerRight : Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
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
