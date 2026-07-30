import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/models/structured_document.dart';
import '../library/library_screen.dart';
import 'dictionary_sheet.dart';
import 'page_turn_animation.dart';
import 'pagination_engine.dart';
import 'reflowable_reader.dart';
import 'pdf_reader.dart';
import '../../domain/parsers/epub_parser.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final int startChapter;
  final int startPage;

  const ReaderScreen({
    super.key,
    required this.bookId,
    this.startChapter = 0,
    this.startPage = 0,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with TickerProviderStateMixin {
  late int _currentChapter;
  bool _showControls = false;
  late AnimationController _controlsAnimation;
  final ScrollController _scrollController = ScrollController();
  DateTime? _sessionStartTime;
  Timer? _readingTimer;
  int _sessionSeconds = 0;

  // Interstitial countdown timer state
  Timer? _interstitialTimer;
  int _interstitialSecondsRemaining = 5;

  // Pagination state
  final PaginationEngine _paginationEngine = PaginationEngine();
  PaginatedChapter? _paginatedChapter;
  late int _currentPage;
  bool _isPaginationReady = false;

  // Structured document state (if available)
  StructuredDocument? _structuredDoc;

  // Pinch gesture state — only activates on 2-finger gestures
  double _pinchStartFontSize = 0;
  bool _isPinching = false;
  double? _pendingFontSize;
  bool _showFontSizeOverlay = false;

  // Key to control the PageTurnWidget dynamically
  final GlobalKey<PageTurnWidgetState> _pageTurnKey = GlobalKey<PageTurnWidgetState>();
  
  bool _isLoadingStructuredDoc = false;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.startChapter;
    _currentPage = widget.startPage;
    _controlsAnimation = AnimationController(
      duration: kFastAnimation,
      vsync: this,
    );
    _sessionStartTime = DateTime.now();
    _startReadingTimer();
    _loadStructuredDoc();
  }

  Future<void> _loadStructuredDoc() async {
    setState(() {
      _isLoadingStructuredDoc = true;
    });
    
    try {
      final repo = ref.read(bookRepositoryProvider);
      final book = repo.getBook(widget.bookId);
      if (book != null && book.format == BookFormat.epub && book.filePath != null) {
        final parser = StructuredEpubParser();
        final result = await parser.parse(File(book.filePath!));
        if (mounted) {
          setState(() {
            _structuredDoc = result.document;
            _isLoadingStructuredDoc = false;
            _isPaginationReady = false;
            _paginatedChapter = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingStructuredDoc = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStructuredDoc = false;
        });
      }
    }
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
    });
  }

  void _startInterstitialTimer(List<Chapter> chapters) {
    _cancelInterstitialTimer();
    setState(() {
      _interstitialSecondsRemaining = 5;
    });
    _interstitialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_interstitialSecondsRemaining > 1) {
        setState(() {
          _interstitialSecondsRemaining--;
        });
      } else {
        timer.cancel();
        _interstitialTimer = null;
        if (_currentChapter < chapters.length - 1) {
          _goToChapter(_currentChapter + 1);
        }
      }
    });
  }

  void _cancelInterstitialTimer() {
    _interstitialTimer?.cancel();
    _interstitialTimer = null;
  }

  @override
  void dispose() {
    _cancelInterstitialTimer();
    _controlsAnimation.dispose();
    _scrollController.dispose();
    _readingTimer?.cancel();
    _saveProgress();
    super.dispose();
  }

  void _saveProgress() {
    final repo = ref.read(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);
    if (chapters.isEmpty) return;

    final progress = repo.getProgress(widget.bookId);

    final updatedRead = Set<int>.from(progress.readChapterIndices)..add(_currentChapter);
    for (int i = 0; i < progress.chaptersCompleted; i++) {
      updatedRead.add(i);
    }

    final totalPages = _paginatedChapter?.pageCount ?? 1;
    final pagePosition = totalPages > 0 ? (_currentPage / totalPages).clamp(0.0, 1.0) : 0.0;

    final overallPercent = _calculateProgress(chapters, ref.read(preferencesRepositoryProvider).settings);

    repo.updateProgress(progress.copyWith(
      currentChapter: _currentChapter,
      positionInChapter: pagePosition,
      overallPercent: overallPercent.clamp(0.0, 1.0),
      chaptersCompleted: updatedRead.length,
      readChapterIndices: updatedRead,
      totalReadingTimeSeconds: progress.totalReadingTimeSeconds + _sessionSeconds,
      lastReadAt: DateTime.now(),
    ));

    final book = repo.getBook(widget.bookId);
    if (book != null) {
      repo.updateBook(book.copyWith(lastOpened: DateTime.now()));
    }

    if (_sessionStartTime != null && _sessionSeconds > 10) {
      repo.addSession(ReadingSession(
        id: 'session_${DateTime.now().millisecondsSinceEpoch}',
        bookId: widget.bookId,
        startedAt: _sessionStartTime!,
        endedAt: DateTime.now(),
        durationSeconds: _sessionSeconds,
        chaptersRead: 1,
        wordsRead: chapters[_currentChapter.clamp(0, chapters.length - 1)].wordCount,
      ));
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _controlsAnimation.forward();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        _controlsAnimation.reverse();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  void _goToChapter(int index, {int? targetPage}) {
    _cancelInterstitialTimer();
    final repo = ref.read(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);
    if (index >= 0 && index < chapters.length) {
      _saveProgress();
      setState(() {
        _currentChapter = index;
        _currentPage = targetPage ?? 0;
        _isPaginationReady = false;
        _paginatedChapter = null;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      _saveProgress();
    }
  }

  void _goToPage(int page) {
    if (_paginatedChapter == null) return;
    final totalPages = _paginatedChapter!.pageCount;
    final clampedPage = page.clamp(0, totalPages);

    if (clampedPage != _currentPage) {
      _cancelInterstitialTimer();
      setState(() {
        _currentPage = clampedPage;
      });
      _saveProgress();

      if (clampedPage == totalPages) {
        final chapters = ref.read(bookRepositoryProvider).getChapters(widget.bookId);
        if (_currentChapter < chapters.length - 1) {
          _startInterstitialTimer(chapters);
        }
      }
    }
  }

  void _nextPageAnimated() {
    _cancelInterstitialTimer();
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final settings = prefsRepo.settings;
    final repo = ref.read(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);

    if (!settings.scrollMode && _paginatedChapter != null) {
      final totalPages = _paginatedChapter!.pageCount;
      if (_currentPage < totalPages) {
        if (_pageTurnKey.currentState != null) {
          _pageTurnKey.currentState!.turnToNext();
        } else {
          _goToPage(_currentPage + 1);
        }
      } else if (_currentChapter < chapters.length - 1) {
        _goToChapter(_currentChapter + 1);
      }
    }
  }

  void _previousPageAnimated() {
    _cancelInterstitialTimer();
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final settings = prefsRepo.settings;

    if (!settings.scrollMode && _paginatedChapter != null) {
      if (_currentPage > 0) {
        if (_pageTurnKey.currentState != null) {
          _pageTurnKey.currentState!.turnToPrevious();
        } else {
          _goToPage(_currentPage - 1);
        }
      } else if (_currentChapter > 0) {
        _goToChapter(_currentChapter - 1, targetPage: 999999);
      }
    }
  }

  void _showReaderSettings() {
    final prefsRepo = ref.read(preferencesRepositoryProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReaderSettingsSheet(
        settings: prefsRepo.settings,
        onChanged: (settings) {
          prefsRepo.saveSettings(settings);
          setState(() {
            _isPaginationReady = false;
            _paginatedChapter = null;
          });
        },
      ),
    );
  }

  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TableOfContentsSheet(
        bookId: widget.bookId,
        currentChapter: _currentChapter,
        onSelectChapter: (index) => _goToChapter(index),
      ),
    );
  }

  void _addBookmark() {
    final repo = ref.read(bookRepositoryProvider);
    final existingBookmarks = repo.getBookmarks(widget.bookId);
    final hasBookmark = existingBookmarks.any((a) => a.chapterIndex == _currentChapter);

    if (hasBookmark) {
      final bookmark = existingBookmarks.firstWhere((a) => a.chapterIndex == _currentChapter);
      repo.removeAnnotation(bookmark.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bookmark removed'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      repo.addAnnotation(Annotation(
        id: 'bookmark_${DateTime.now().millisecondsSinceEpoch}',
        bookId: widget.bookId,
        chapterIndex: _currentChapter,
        type: AnnotationType.bookmark,
        position: 0,
        createdAt: DateTime.now(),
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bookmark added'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    setState(() {});
  }

  void _lookupWord(String word) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _DictionaryLookupSheet(word: word),
    );
  }

  // ─── Robust Pinch-to-Zoom ─────────────────────────────────────────────

  void _onPinchStart(ScaleStartDetails details, ReaderSettings settings) {
    if (details.pointerCount >= 2) {
      _pinchStartFontSize = settings.fontSize;
      _isPinching = true;
      _pendingFontSize = settings.fontSize;
      setState(() => _showFontSizeOverlay = true);
    } else {
      _isPinching = false;
      _pendingFontSize = null;
    }
  }

  void _onPinchUpdate(ScaleUpdateDetails details) {
    if (!_isPinching) return;
    if (details.pointerCount >= 2) {
      final newSize = (_pinchStartFontSize * details.scale).clamp(kMinFontSize, kMaxFontSize);
      setState(() {
        _pendingFontSize = newSize;
      });
    }
  }

  void _onPinchEnd(ScaleEndDetails details, PreferencesRepository prefsRepo) {
    if (_isPinching) {
      _isPinching = false;
      if (_pendingFontSize != null) {
        final settings = prefsRepo.settings;
        prefsRepo.saveSettings(settings.copyWith(fontSize: _pendingFontSize));
        setState(() {
          _isPaginationReady = false;
          _paginatedChapter = null;
          _showFontSizeOverlay = false;
          _pendingFontSize = null;
        });
      } else {
        setState(() {
          _showFontSizeOverlay = false;
          _pendingFontSize = null;
        });
      }
    }
  }

  DocumentSection _buildStructuredSection(Chapter chapter) {
    if (_structuredDoc != null &&
        _currentChapter < _structuredDoc!.sections.length) {
      return _structuredDoc!.sections[_currentChapter];
    }

    final paragraphs = chapter.content.split('\n\n');
    final blocks = paragraphs
        .where((p) => p.trim().isNotEmpty)
        .map((p) => ContentBlock.paragraph([DocInlineSpan(text: p.trim())]))
        .toList();

    return DocumentSection(
      id: 'section_${chapter.index}',
      title: chapter.title,
      index: chapter.index,
      contentBlocks: blocks,
      wordCount: chapter.wordCount,
    );
  }

  void _repaginate(
    DocumentSection section,
    Size viewportSize,
    ReaderSettings settings,
  ) {
    if (_isPaginationReady) return;

    final margin = settings.margin;
    // Reserved height (140px) accounts for top padding, bottom indicator, and safe buffer
    final contentSize = Size(
      viewportSize.width - margin * 2,
      viewportSize.height - 140,
    );

    _paginatedChapter = _paginationEngine.paginate(
      section: section,
      viewportSize: contentSize,
      settings: settings,
    );
    _isPaginationReady = true;

    if (_paginatedChapter != null) {
      if (_currentPage >= 99999) {
        _currentPage = _paginatedChapter!.pageCount;
      } else {
        _currentPage = _currentPage.clamp(0, _paginatedChapter!.pageCount);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(bookRepositoryProvider);
    final book = repo.getBook(widget.bookId);
    final chapters = repo.getChapters(widget.bookId);
    final prefsRepo = ref.watch(preferencesRepositoryProvider);
    final settings = prefsRepo.settings;
    final bookmarks = repo.getBookmarks(widget.bookId);
    final hasBookmark = bookmarks.any((a) => a.chapterIndex == _currentChapter);

    if (book == null || chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Book not found')),
      );
    }

    final readingTheme = settings.readingTheme;

    if (_isLoadingStructuredDoc) {
      return Scaffold(
        backgroundColor: readingTheme.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final chapter = chapters[_currentChapter.clamp(0, chapters.length - 1)];
    final isPdf = book.format == BookFormat.pdf;

    Widget readingSurface;
    if (isPdf) {
      readingSurface = _buildPdfReader(book, readingTheme);
    } else if (settings.scrollMode) {
      readingSurface = _buildScrollReader(chapter, settings, readingTheme, repo);
    } else {
      readingSurface = _buildPaginatedReader(chapter, settings, readingTheme, repo, chapters);
    }

    final barColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _saveProgress();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      child: Scaffold(
        backgroundColor: readingTheme.backgroundColor,
        body: Stack(
          children: [
            // Reading content with pinch gestures
            GestureDetector(
              onScaleStart: !isPdf ? (details) => _onPinchStart(details, settings) : null,
              onScaleUpdate: !isPdf ? (details) => _onPinchUpdate(details) : null,
              onScaleEnd: !isPdf ? (details) => _onPinchEnd(details, prefsRepo) : null,
              child: readingSurface,
            ),

            // Top tap zone overlay for 100% reliable menu toggle (above text selection)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleControls,
              ),
            ),

            // Font size overlay during pinch
            if (_showFontSizeOverlay && _pendingFontSize != null)
              Center(
                child: AnimatedOpacity(
                  opacity: _showFontSizeOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.format_size, color: Theme.of(context).colorScheme.primary, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          '${_pendingFontSize!.round()} px',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Controls overlay
            if (_showControls) ...[
              // Floating Top Bar (Flat application tone + rounded corners)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: AnimatedBuilder(
                  animation: _controlsAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _controlsAnimation,
                      child: Material(
                        elevation: 6,
                        color: barColor,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back, color: textColor),
                                onPressed: () {
                                  _saveProgress();
                                  ref.read(libraryRefreshProvider.notifier).state++;
                                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                                  Navigator.pop(context);
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      book.title,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      chapter.title,
                                      style: TextStyle(
                                        color: textColor.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  hasBookmark ? Icons.bookmark : Icons.bookmark_outline,
                                  color: hasBookmark ? Theme.of(context).colorScheme.primary : textColor,
                                ),
                                onPressed: _addBookmark,
                              ),
                              PopupMenuButton(
                                icon: Icon(Icons.more_vert, color: textColor),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'toc',
                                    child: ListTile(
                                      leading: Icon(Icons.list, color: textColor),
                                      title: Text('Table of Contents', style: TextStyle(color: textColor)),
                                      dense: true,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'settings',
                                    child: ListTile(
                                      leading: Icon(Icons.text_format, color: textColor),
                                      title: Text('Reader Settings', style: TextStyle(color: textColor)),
                                      dense: true,
                                    ),
                                  ),
                                  if (!isPdf)
                                    PopupMenuItem(
                                      value: 'rsvp',
                                      child: ListTile(
                                        leading: Icon(Icons.speed, color: textColor),
                                        title: Text('RSVP Mode', style: TextStyle(color: textColor)),
                                        dense: true,
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'details',
                                    child: ListTile(
                                      leading: Icon(Icons.info_outline, color: textColor),
                                      title: Text('Book Details', style: TextStyle(color: textColor)),
                                      dense: true,
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  switch (value) {
                                    case 'toc':
                                      _showTableOfContents();
                                    case 'settings':
                                      _showReaderSettings();
                                    case 'rsvp':
                                      _saveProgress();
                                      Navigator.pushNamed(context, '/rsvp', arguments: {
                                        'bookId': widget.bookId,
                                        'chapterIndex': _currentChapter,
                                      });
                                    case 'details':
                                      Navigator.pushNamed(context, '/book-details', arguments: widget.bookId);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Floating Bottom Bar (Flat application tone + rounded corners)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                left: 12,
                right: 12,
                child: AnimatedBuilder(
                  animation: _controlsAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _controlsAnimation,
                      child: Material(
                        elevation: 6,
                        color: barColor,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Page progress slider row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.skip_previous_rounded,
                                          color: textColor.withValues(alpha: 0.8), size: 22),
                                      onPressed: _currentChapter > 0
                                          ? () => _goToChapter(_currentChapter - 1)
                                          : null,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    ),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        _getPositionLabel(settings, chapters),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          activeTrackColor: Theme.of(context).colorScheme.primary,
                                          inactiveTrackColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                                          thumbColor: Theme.of(context).colorScheme.primary,
                                          trackHeight: 3,
                                          thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 6,
                                            elevation: 2,
                                          ),
                                          overlayShape: const RoundSliderOverlayShape(
                                            overlayRadius: 16,
                                          ),
                                        ),
                                        child: Slider(
                                          value: _getSliderValue(settings, chapters),
                                          min: 0,
                                          max: _getSliderMax(settings, chapters),
                                          divisions: _getSliderDivisions(settings, chapters),
                                          onChanged: (value) {
                                            _onSliderChanged(value, settings, chapters);
                                          },
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        _getMaxLabel(settings, chapters),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textColor.withValues(alpha: 0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.skip_next_rounded,
                                          color: textColor.withValues(alpha: 0.8), size: 22),
                                      onPressed: _currentChapter < chapters.length - 1
                                          ? () => _goToChapter(_currentChapter + 1)
                                          : null,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 8,
                                indent: 16,
                                endIndent: 16,
                                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                              // Bottom toolbar icons
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _ToolbarButton(
                                      icon: Icons.format_list_bulleted,
                                      label: 'Contents',
                                      onTap: _showTableOfContents,
                                      textColor: textColor,
                                    ),
                                    _ToolbarButton(
                                      icon: Icons.text_format,
                                      label: 'Display',
                                      onTap: _showReaderSettings,
                                      textColor: textColor,
                                    ),
                                    _ToolbarButton(
                                      icon: hasBookmark ? Icons.bookmark : Icons.bookmark_outline,
                                      label: 'Bookmark',
                                      onTap: _addBookmark,
                                      isActive: hasBookmark,
                                      textColor: textColor,
                                    ),
                                    _ToolbarButton(
                                      icon: Icons.settings_outlined,
                                      label: 'More',
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          builder: (_) => _MoreOptionsSheet(
                                            bookId: widget.bookId,
                                            currentChapter: _currentChapter,
                                            isPdf: isPdf,
                                            onSaveProgress: _saveProgress,
                                          ),
                                        );
                                      },
                                      textColor: textColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Paginated Reader ─────────────────────────────────────────────────

  Widget _buildPaginatedReader(
    Chapter chapter,
    ReaderSettings settings,
    ReadingTheme readingTheme,
    BookRepository repo,
    List<Chapter> chapters,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final section = _buildStructuredSection(chapter);
        _repaginate(
          section,
          Size(constraints.maxWidth, constraints.maxHeight),
          settings,
        );

        if (_paginatedChapter == null || _paginatedChapter!.pages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final totalPages = _paginatedChapter!.pageCount;

        Widget buildSinglePage(int pageIndex) {
          if (pageIndex < totalPages) {
            final page = _paginatedChapter!.pages[pageIndex];
            return Container(
              color: readingTheme.backgroundColor,
              padding: EdgeInsets.fromLTRB(
                settings.margin,
                24,
                settings.margin,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Expanded(
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: ContentBlockRenderer(
                          blocks: page.blocks,
                          settings: settings,
                          readingTheme: readingTheme,
                          images: _structuredDoc?.images ?? const {},
                          onWordLookup: _lookupWord,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 44),
                      child: Text(
                        '${_currentChapter + 1} · ${pageIndex + 1} / $totalPages',
                        style: TextStyle(
                          color: readingTheme.textColor.withValues(alpha: 0.35),
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return _buildInterstitialPage(chapters, readingTheme, settings);
          }
        }

        final maxPagesInChapter = totalPages + (_currentChapter < chapters.length - 1 ? 1 : 0);

        return Stack(
          children: [
            PageTurnWidget(
              key: _pageTurnKey,
              currentPage: _currentPage.clamp(0, maxPagesInChapter),
              totalPages: maxPagesInChapter,
              pageBuilder: buildSinglePage,
              onPageChanged: (newPage) {
                if (newPage > totalPages) {
                  _goToChapter(_currentChapter + 1);
                } else if (newPage < 0) {
                  if (_currentChapter > 0) {
                    _goToChapter(_currentChapter - 1, targetPage: 999999);
                  }
                } else {
                  _goToPage(newPage);
                }
              },
            ),
            // Bottom 78% tap zone for tap-navigation (left 1/3 -> prev, right 2/3 -> next)
            Positioned(
              top: constraints.maxHeight * 0.22,
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _previousPageAnimated,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _nextPageAnimated,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Paper-Friendly Interstitial Chapter Transition Page ────────────

  Widget _buildInterstitialPage(List<Chapter> chapters, ReadingTheme readingTheme, ReaderSettings settings) {
    final currentChapterObj = chapters[_currentChapter.clamp(0, chapters.length - 1)];
    final hasNext = _currentChapter < chapters.length - 1;
    final nextChapterObj = hasNext ? chapters[_currentChapter + 1] : null;

    final bgColor = readingTheme.backgroundColor;
    final textColor = readingTheme.textColor;

    return Container(
      color: bgColor,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Paper Ornament Check Icon
              Icon(
                Icons.check_circle_outline,
                color: textColor.withValues(alpha: 0.5),
                size: 38,
              ),
              const SizedBox(height: 16),
              Text(
                'END OF CHAPTER ${_currentChapter + 1}',
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  color: textColor.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentChapterObj.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 36),

              if (hasNext && nextChapterObj != null) ...[
                Text(
                  'UP NEXT',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    color: textColor.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chapter ${_currentChapter + 2}: ${nextChapterObj.title}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          value: _interstitialSecondsRemaining / 5.0,
                          strokeWidth: 2,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Next chapter in ${_interstitialSecondsRemaining}s (slide to skip)',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  '🎉 End of Book',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have completed this entire book.',
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.library_books),
                  label: const Text('Back to Library'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Scroll Reader ────────────────────────────────────────────────────

  Widget _buildScrollReader(
    Chapter chapter,
    ReaderSettings settings,
    ReadingTheme readingTheme,
    BookRepository repo,
  ) {
    final section = _buildStructuredSection(chapter);
    final chapters = repo.getChapters(widget.bookId);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: settings.margin,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            chapter.title,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontSize: settings.fontSize + 6,
              fontWeight: FontWeight.bold,
              color: readingTheme.textColor,
              height: 1.3,
            ),
          ),
          SizedBox(height: settings.paragraphSpacing + 8),
          ContentBlockRenderer(
            blocks: section.contentBlocks,
            settings: settings,
            readingTheme: readingTheme,
            images: _structuredDoc?.images ?? const {},
            onWordLookup: _lookupWord,
          ),
          SizedBox(height: settings.paragraphSpacing * 2),
          Divider(color: readingTheme.textColor.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentChapter > 0)
                TextButton.icon(
                  onPressed: () => _goToChapter(_currentChapter - 1),
                  icon: Icon(Icons.arrow_back, color: readingTheme.textColor.withValues(alpha: 0.6)),
                  label: Text(
                    'Previous',
                    style: TextStyle(color: readingTheme.textColor.withValues(alpha: 0.6)),
                  ),
                )
              else
                const SizedBox(),
              Text(
                'Chapter ${_currentChapter + 1} of ${chapters.length}',
                style: TextStyle(
                  color: readingTheme.textColor.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              if (_currentChapter < chapters.length - 1)
                TextButton.icon(
                  onPressed: () => _goToChapter(_currentChapter + 1),
                  icon: Text(
                    'Next',
                    style: TextStyle(color: readingTheme.textColor.withValues(alpha: 0.6)),
                  ),
                  label: Icon(Icons.arrow_forward, color: readingTheme.textColor.withValues(alpha: 0.6)),
                )
              else
                const SizedBox(),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ─── PDF Reader ───────────────────────────────────────────────────────

  Widget _buildPdfReader(Book book, ReadingTheme readingTheme) {
    final filePath = book.filePath ?? book.description ?? '';
    final file = File(filePath);

    if (filePath.isNotEmpty && file.existsSync()) {
      return PdfReaderWidget(
        filePath: filePath,
        readingTheme: readingTheme,
        initialPage: _currentPage,
        onCenterTap: _toggleControls,
        onPageChanged: (page, totalPages) {
          setState(() {
            _currentPage = page;
          });
        },
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: readingTheme.textColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            book.title,
            style: TextStyle(
              color: readingTheme.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PDF document ready for reading.',
            style: TextStyle(
              color: readingTheme.textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Slider Helpers ───────────────────────────────────────────────────

  double _calculateProgress(List<Chapter> chapters, ReaderSettings settings) {
    if (!settings.scrollMode && _paginatedChapter != null && _paginatedChapter!.pageCount > 0) {
      final chapterFraction = 1.0 / chapters.length;
      final pageFraction = (_currentPage + 1) / _paginatedChapter!.pageCount;
      return (_currentChapter * chapterFraction + pageFraction * chapterFraction).clamp(0.0, 1.0);
    }
    return ((_currentChapter + 1) / chapters.length).clamp(0.0, 1.0);
  }

  String _getPositionLabel(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      return '${_currentPage + 1}';
    }
    return '${_currentChapter + 1}';
  }

  String _getMaxLabel(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      return '${_paginatedChapter!.pageCount}';
    }
    return '${chapters.length}';
  }

  double _getSliderValue(ReaderSettings settings, List<Chapter> chapters) {
    final max = _getSliderMax(settings, chapters);
    if (!settings.scrollMode && _paginatedChapter != null) {
      return _currentPage.toDouble().clamp(0.0, max);
    }
    return _currentChapter.toDouble().clamp(0.0, max);
  }

  double _getSliderMax(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      final count = _paginatedChapter!.pageCount;
      return count > 1 ? (count - 1).toDouble() : 0.0;
    }
    final count = chapters.length;
    return count > 1 ? (count - 1).toDouble() : 0.0;
  }

  int? _getSliderDivisions(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      final count = _paginatedChapter!.pageCount;
      return count > 1 ? count - 1 : null;
    }
    final count = chapters.length;
    return count > 1 ? count - 1 : null;
  }

  void _onSliderChanged(double value, ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      _goToPage(value.toInt());
    } else {
      _goToChapter(value.toInt());
    }
  }
}



// ─── Toolbar Button ────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color textColor;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : textColor.withValues(alpha: 0.8),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : textColor.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── More Options Sheet ────────────────────────────────────────────────

class _MoreOptionsSheet extends StatelessWidget {
  final String bookId;
  final int currentChapter;
  final bool isPdf;
  final VoidCallback onSaveProgress;

  const _MoreOptionsSheet({
    required this.bookId,
    required this.currentChapter,
    required this.isPdf,
    required this.onSaveProgress,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (!isPdf)
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('RSVP Mode'),
              subtitle: const Text('Speed reading with word flashing'),
              onTap: () {
                Navigator.pop(context);
                onSaveProgress();
                Navigator.pushNamed(context, '/rsvp', arguments: {
                  'bookId': bookId,
                  'chapterIndex': currentChapter,
                });
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Book Details'),
            subtitle: const Text('View book info and annotations'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/book-details', arguments: bookId);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Dictionary Lookup Sheet (with loading) ────────────────────────────

class _DictionaryLookupSheet extends ConsumerStatefulWidget {
  final String word;

  const _DictionaryLookupSheet({required this.word});

  @override
  ConsumerState<_DictionaryLookupSheet> createState() => _DictionaryLookupSheetState();
}

class _DictionaryLookupSheetState extends ConsumerState<_DictionaryLookupSheet> {
  bool _isLoading = true;
  DictionaryEntry? _entry;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    try {
      final dictService = ref.read(dictionaryServiceProvider);
      final entry = await dictService.define(widget.word);
      if (mounted) {
        setState(() {
          _entry = entry;
          _isLoading = false;
          if (entry == null) {
            _error = 'No definition found for "${widget.word}".';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not look up "${widget.word}". Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DictionarySheet(
      word: widget.word,
      entry: _entry,
      isLoading: _isLoading,
      errorMessage: _error,
    );
  }
}

// ─── Reader Settings Sheet ──────────────────────────────────────────────

class _ReaderSettingsSheet extends StatefulWidget {
  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  const _ReaderSettingsSheet({
    required this.settings,
    required this.onChanged,
  });

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late ReaderSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(ReaderSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text('Reader Settings',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 20),

                // Reading mode toggle
                Text('Reading Mode', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.auto_stories),
                      label: Text('Paginated'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.view_stream),
                      label: Text('Scroll'),
                    ),
                  ],
                  selected: {_settings.scrollMode},
                  onSelectionChanged: (set) {
                    _update(_settings.copyWith(scrollMode: set.first));
                  },
                ),
                const SizedBox(height: 20),

                // Theme presets
                Text('Theme', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ReadingTheme.values.map((theme) {
                    final isSelected = _settings.readingTheme == theme;
                    return GestureDetector(
                      onTap: () => _update(_settings.copyWith(readingTheme: theme)),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: kFastAnimation,
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: theme.backgroundColor,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: isSelected ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'Aa',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme.label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Font family
                Text('Font Family', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Serif', label: Text('Serif')),
                    ButtonSegment(value: 'Sans', label: Text('Sans')),
                    ButtonSegment(value: 'Mono', label: Text('Mono')),
                  ],
                  selected: {
                    _settings.fontFamily == 'monospace' ? 'Mono' :
                    _settings.fontFamily == 'sans-serif' ? 'Sans' : 'Serif',
                  },
                  onSelectionChanged: (set) {
                    final family = set.first == 'Mono' ? 'monospace' :
                        set.first == 'Sans' ? 'sans-serif' : 'serif';
                    _update(_settings.copyWith(fontFamily: family));
                  },
                ),

                const SizedBox(height: 20),

                // Font size
                _SettingsSlider(
                  label: 'Font Size',
                  value: _settings.fontSize,
                  min: kMinFontSize,
                  max: kMaxFontSize,
                  displayValue: '${_settings.fontSize.round()}',
                  onChanged: (v) => _update(_settings.copyWith(fontSize: v)),
                ),

                // Line height
                _SettingsSlider(
                  label: 'Line Spacing',
                  value: _settings.lineHeight,
                  min: kMinLineHeight,
                  max: kMaxLineHeight,
                  displayValue: _settings.lineHeight.toStringAsFixed(1),
                  onChanged: (v) => _update(_settings.copyWith(lineHeight: v)),
                ),

                // Margins
                _SettingsSlider(
                  label: 'Margins',
                  value: _settings.margin,
                  min: kMinMargin,
                  max: kMaxMargin,
                  displayValue: '${_settings.margin.round()}',
                  onChanged: (v) => _update(_settings.copyWith(margin: v)),
                ),

                const SizedBox(height: 12),

                // Text alignment
                Text('Text Alignment', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<ReaderTextAlign>(
                  segments: ReaderTextAlign.values.map((a) {
                    return ButtonSegment(
                      value: a,
                      icon: Icon(
                        a == ReaderTextAlign.left
                            ? Icons.format_align_left
                            : a == ReaderTextAlign.center
                                ? Icons.format_align_center
                                : Icons.format_align_justify,
                      ),
                    );
                  }).toList(),
                  selected: {_settings.textAlign},
                  onSelectionChanged: (set) {
                    _update(_settings.copyWith(textAlign: set.first));
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(displayValue, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          Slider(
            value: clampedValue,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Table of Contents Sheet ──────────────────────────────────────────

class _TableOfContentsSheet extends ConsumerStatefulWidget {
  final String bookId;
  final int currentChapter;
  final void Function(int chapterIndex) onSelectChapter;

  const _TableOfContentsSheet({
    required this.bookId,
    required this.currentChapter,
    required this.onSelectChapter,
  });

  @override
  ConsumerState<_TableOfContentsSheet> createState() => _TableOfContentsSheetState();
}

class _TableOfContentsSheetState extends ConsumerState<_TableOfContentsSheet> {
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _startSelectionMode(int initialIndex) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.add(initialIndex);
    });
  }

  void _selectAll(int totalChapters) {
    setState(() {
      _selectedIndices.addAll(List.generate(totalChapters, (i) => i));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
      _isSelectionMode = false;
    });
  }

  void _batchMarkRead() {
    final repo = ref.read(bookRepositoryProvider);
    repo.markChaptersRead(widget.bookId, _selectedIndices);
    _clearSelection();
  }

  void _batchMarkUnread() {
    final repo = ref.read(bookRepositoryProvider);
    repo.markChaptersUnread(widget.bookId, _selectedIndices);
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);
    final progress = repo.getProgress(widget.bookId);
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (_isSelectionMode)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                  ),
                  Text(
                    '${_selectedIndices.length} selected',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      if (_selectedIndices.length == chapters.length) {
                        _clearSelection();
                      } else {
                        _selectAll(chapters.length);
                      }
                    },
                    child: Text(_selectedIndices.length == chapters.length ? 'Deselect All' : 'Select All'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Mark Selected as Read',
                    onPressed: _selectedIndices.isNotEmpty ? _batchMarkRead : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.highlight_off),
                    tooltip: 'Mark Selected as Unread',
                    onPressed: _selectedIndices.isNotEmpty ? _batchMarkUnread : null,
                  ),
                ],
              )
            else
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Table of Contents',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            const Divider(),

            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (ctx, index) {
                  final chapter = chapters[index];
                  final isCurrent = index == widget.currentChapter;
                  final isRead = progress.isChapterRead(index);
                  final isSelected = _selectedIndices.contains(index);

                  double chapterProgress = 0.0;
                  if (isRead) {
                    chapterProgress = 1.0;
                  } else if (isCurrent) {
                    chapterProgress = progress.positionInChapter.clamp(0.0, 1.0);
                  }

                  final textColor = isRead
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                      : theme.colorScheme.onSurface;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: _isSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(index),
                          )
                        : CircleAvatar(
                            radius: 14,
                            backgroundColor: isCurrent
                                ? theme.colorScheme.primary
                                : isRead
                                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                    : theme.colorScheme.surfaceContainerHigh,
                            child: isRead && !isCurrent
                                ? Icon(Icons.check, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5))
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isCurrent
                                          ? theme.colorScheme.onPrimary
                                          : textColor,
                                    ),
                                  ),
                          ),
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: chapterProgress,
                                  minHeight: 4,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  color: isRead
                                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isRead
                                  ? 'Done'
                                  : isCurrent
                                      ? '${(chapterProgress * 100).round()}%'
                                      : 'Not started',
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withValues(alpha: isRead ? 0.35 : 0.6),
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: _isSelectionMode
                        ? null
                        : IconButton(
                            icon: Icon(
                              isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isRead
                                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                              size: 20,
                            ),
                            tooltip: isRead ? 'Mark as Unread' : 'Mark as Read',
                            onPressed: () {
                              repo.toggleChapterRead(widget.bookId, index);
                            },
                          ),
                    selected: isSelected || (isCurrent && !_isSelectionMode),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(index);
                      } else {
                        Navigator.pop(ctx);
                        widget.onSelectChapter(index);
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        _startSelectionMode(index);
                      } else {
                        _toggleSelection(index);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
