import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/constants.dart';

/// PDF reader widget that wraps pdfrx for fixed-layout document rendering.
/// Supports page navigation, pinch-to-zoom, pan, and text selection.
class PdfReaderWidget extends StatefulWidget {
  final String filePath;
  final ReadingTheme readingTheme;
  final int initialPage;
  final void Function(int page, int totalPages)? onPageChanged;
  final void Function(String word)? onWordLookup;
  final VoidCallback? onCenterTap;
  final bool isScrollMode;

  const PdfReaderWidget({
    super.key,
    required this.filePath,
    required this.readingTheme,
    this.initialPage = 0,
    this.onPageChanged,
    this.onWordLookup,
    this.onCenterTap,
    this.isScrollMode = false,
  });

  @override
  State<PdfReaderWidget> createState() => _PdfReaderWidgetState();
}

class _PdfReaderWidgetState extends State<PdfReaderWidget> {
  late final PdfViewerController _controller;
  late final PageController _pageController;
  PdfDocument? _pdfDocument;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoadingDoc = true;
  String _selectedPdfText = '';

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _loadPdfDocument();
  }

  Future<void> _loadPdfDocument() async {
    try {
      final doc = await PdfDocument.openFile(widget.filePath);
      if (mounted) {
        setState(() {
          _pdfDocument = doc;
          _totalPages = doc.pages.length;
          _isLoadingDoc = false;
        });
        widget.onPageChanged?.call(_currentPage, _totalPages);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDoc = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PdfReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isScrollMode != widget.isScrollMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!widget.isScrollMode && _pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        } else if (widget.isScrollMode) {
          _controller.goToPage(pageNumber: _currentPage + 1);
        }
      });
    }
  }

  Widget _buildSelectionInjector(BuildContext context, Widget child) {
    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedPdfText = content?.plainText.trim() ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        return AdaptiveTextSelectionToolbar(
          anchors: selectableRegionState.contextMenuAnchors,
          children: [
            if (_selectedPdfText.isNotEmpty && _selectedPdfText.split(RegExp(r'\s+')).length <= 3 && widget.onWordLookup != null)
              TextButton.icon(
                onPressed: () {
                  selectableRegionState.hideToolbar();
                  widget.onWordLookup!(_selectedPdfText);
                },
                icon: const Icon(Icons.book, size: 16),
                label: const Text('Define', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            if (_selectedPdfText.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _selectedPdfText));
                  selectableRegionState.hideToolbar();
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDoc) {
      return Container(
        color: widget.readingTheme.backgroundColor,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      children: [
        // Main Viewer
        Container(
          color: widget.readingTheme.backgroundColor,
          child: !widget.isScrollMode ? _buildPageFlipViewer() : _buildScrollViewer(),
        ),

          // Center Tap Detector (Transparent overlay for controls toggle without blocking gestures)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                final size = MediaQuery.of(context).size;
                final tapX = details.globalPosition.dx;
                final tapY = details.globalPosition.dy;
                final centerX = size.width / 2;
                final centerY = size.height / 2;

                if ((tapX - centerX).abs() < size.width / 6 &&
                    (tapY - centerY).abs() < size.height / 6) {
                  widget.onCenterTap?.call();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),


          // Page Indicator (Bottom Center)
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

  /// Page-by-page snapping viewer using PageView and PdfPageView
  Widget _buildPageFlipViewer() {
    if (_pdfDocument == null || _totalPages == 0) {
      return const Center(child: Text('Empty document'));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _totalPages,
      onPageChanged: (pageIndex) {
        setState(() => _currentPage = pageIndex);
        widget.onPageChanged?.call(_currentPage, _totalPages);
      },
      itemBuilder: (context, index) {
        return Center(
          child: PdfPageView(
            document: _pdfDocument!,
            pageNumber: index + 1,
            maximumDpi: 300,
          ),
        );
      },
    );
  }

  /// Continuous scroll viewer using pdfrx PdfViewer
  Widget _buildScrollViewer() {
    return PdfViewer.file(
      widget.filePath,
      controller: _controller,
      params: PdfViewerParams(
        enableTextSelection: true,
        selectableRegionInjector: _buildSelectionInjector,
        onPageChanged: (page) {
          if (page != null) {
            setState(() => _currentPage = page - 1);
            widget.onPageChanged?.call(_currentPage, _totalPages);
          }
        },
        onViewerReady: (document, controller) {
          _totalPages = document.pages.length;
          if (_currentPage >= 0 && _currentPage < _totalPages) {
            controller.goToPage(pageNumber: _currentPage + 1);
          }
          widget.onPageChanged?.call(_currentPage, _totalPages);
          setState(() {});
        },
      ),
    );
  }

  /// Navigate to a specific page.
  void goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _currentPage = page;
      if (!widget.isScrollMode && _pageController.hasClients) {
        _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else {
        _controller.goToPage(pageNumber: page + 1);
      }
    }
  }

  /// Get current page index.
  int get currentPage => _currentPage;

  /// Get total page count.
  int get totalPages => _totalPages;
}
