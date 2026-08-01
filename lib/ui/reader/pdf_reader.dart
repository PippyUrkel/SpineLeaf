import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/constants.dart';

/// PDF reader widget that wraps pdfrx for fixed-layout document rendering.
/// Supports page navigation, pinch-to-zoom, pan, and text selection in both
/// page-flip and continuous scroll modes.
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
  late final PdfViewerController _scrollController;
  late final PageController _pageController;
  PdfDocument? _pdfDocument;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoadingDoc = true;
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _scrollController = PdfViewerController();
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
        } else if (widget.isScrollMode && _totalPages > 0) {
          _scrollController.goToPage(pageNumber: _currentPage + 1);
        }
      });
    }
  }

  // ─── Shared Selection Injector ─────────────────────────────────────────

  Widget _selectionInjector(BuildContext context, Widget child) {
    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedText = content?.plainText.trim() ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        return AdaptiveTextSelectionToolbar(
          anchors: selectableRegionState.contextMenuAnchors,
          children: [
            if (_selectedText.isNotEmpty &&
                _selectedText.split(RegExp(r'\s+')).length <= 3 &&
                widget.onWordLookup != null)
              TextButton.icon(
                onPressed: () {
                  selectableRegionState.hideToolbar();
                  widget.onWordLookup!(_selectedText);
                },
                icon: const Icon(Icons.book, size: 16),
                label: const Text('Define', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            if (_selectedText.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _selectedText));
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

  // ─── Build ─────────────────────────────────────────────────────────────

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
        Container(
          color: widget.readingTheme.backgroundColor,
          child: widget.isScrollMode
              ? _buildScrollViewer()
              : _buildPageFlipViewer(),
        ),

        // Center tap detector — transparent overlay so gestures pass through
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final size = MediaQuery.of(context).size;
              final tapX = details.globalPosition.dx;
              final tapY = details.globalPosition.dy;
              if ((tapX - size.width / 2).abs() < size.width / 6 &&
                  (tapY - size.height / 2).abs() < size.height / 6) {
                widget.onCenterTap?.call();
              }
            },
            child: const SizedBox.expand(),
          ),
        ),

        // Page indicator
        if (_totalPages > 0)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Page-Flip Viewer ──────────────────────────────────────────────────

  /// Page-by-page viewer with pinch-to-zoom (InteractiveViewer) and
  /// text selection on each page. 
  Widget _buildPageFlipViewer() {
    if (_pdfDocument == null || _totalPages == 0) {
      return const Center(child: Text('Empty document'));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _totalPages,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        widget.onPageChanged?.call(_currentPage, _totalPages);
      },
      itemBuilder: (context, index) {
        return _buildZoomablePage(index);
      },
    );
  }

  Widget _buildZoomablePage(int index) {
    return _selectionInjector(
      context,
      InteractiveViewer(
        minScale: 1.0,
        maxScale: 5.0,
        // Allow panning only when zoomed in; don't steal swipe from PageView
        panEnabled: true,
        scaleEnabled: true,
        child: Center(
          child: PdfPageView(
            document: _pdfDocument,
            pageNumber: index + 1,
            maximumDpi: 300,
          ),
        ),
      ),
    );
  }

  // ─── Continuous Scroll Viewer ──────────────────────────────────────────

  /// Continuous scroll viewer using PdfViewer — already handles pinch-zoom
  /// natively. We wire in the shared selection injector for dictionary support.
  Widget _buildScrollViewer() {
    return PdfViewer.file(
      widget.filePath,
      controller: _scrollController,
      params: PdfViewerParams(
        enableTextSelection: true,
        selectableRegionInjector: _selectionInjector,
        onPageChanged: (page) {
          if (page != null) {
            setState(() => _currentPage = page - 1);
            widget.onPageChanged?.call(_currentPage, _totalPages);
          }
        },
        onViewerReady: (document, controller) {
          final total = document.pages.length;
          setState(() => _totalPages = total);
          if (_currentPage >= 0 && _currentPage < total) {
            controller.goToPage(pageNumber: _currentPage + 1);
          }
          widget.onPageChanged?.call(_currentPage, _totalPages);
        },
      ),
    );
  }

  // ─── Public API ────────────────────────────────────────────────────────

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
        _scrollController.goToPage(pageNumber: page + 1);
      }
    }
  }

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
}
