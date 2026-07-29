import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/constants.dart';

/// PDF reader widget that wraps pdfrx for fixed-layout document rendering.
/// Supports page navigation, pinch-to-zoom, pan, and text selection.
class PdfReaderWidget extends StatefulWidget {
  final String filePath;
  final ReadingTheme readingTheme;
  final int initialPage;
  final void Function(int page, int totalPages)? onPageChanged;
  final VoidCallback? onCenterTap;

  const PdfReaderWidget({
    super.key,
    required this.filePath,
    required this.readingTheme,
    this.initialPage = 0,
    this.onPageChanged,
    this.onCenterTap,
  });

  @override
  State<PdfReaderWidget> createState() => _PdfReaderWidgetState();
}

class _PdfReaderWidgetState extends State<PdfReaderWidget> {
  late final PdfViewerController _controller;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _currentPage = widget.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // PDF viewer
        GestureDetector(
          onTapUp: (details) {
            // Center tap detection for controls toggle
            final size = MediaQuery.of(context).size;
            final tapX = details.globalPosition.dx;
            final tapY = details.globalPosition.dy;
            final centerX = size.width / 2;
            final centerY = size.height / 2;

            // Center 1/3 of the screen
            if ((tapX - centerX).abs() < size.width / 6 &&
                (tapY - centerY).abs() < size.height / 6) {
              widget.onCenterTap?.call();
            }
          },
          child: PdfViewer.file(
            widget.filePath,
            controller: _controller,
            params: PdfViewerParams(
              onPageChanged: (page) {
                if (page != null) {
                  setState(() => _currentPage = page - 1);
                  widget.onPageChanged?.call(_currentPage, _totalPages);
                }
              },
              onViewerReady: (document, controller) {
                _totalPages = document.pages.length;
                if (widget.initialPage > 0 && widget.initialPage < _totalPages) {
                  controller.goToPage(pageNumber: widget.initialPage + 1);
                }
                widget.onPageChanged?.call(_currentPage, _totalPages);
                setState(() {});
              },
            ),
          ),
        ),

        // Page indicator
        if (_totalPages > 0)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Navigate to a specific page.
  void goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _controller.goToPage(pageNumber: page + 1);
    }
  }

  /// Get current page index.
  int get currentPage => _currentPage;

  /// Get total page count.
  int get totalPages => _totalPages;
}
