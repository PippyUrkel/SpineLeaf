import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/models/structured_document.dart';
import '../library/library_screen.dart';
import 'dictionary_sheet.dart';
import 'pagination_engine.dart';
import 'reflowable_reader.dart';
import 'pdf_reader.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final int startChapter;

  const ReaderScreen({
    super.key,
    required this.bookId,
    this.startChapter = 0,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  late int _currentChapter;
  bool _showControls = false;
  late AnimationController _controlsAnimation;
  final ScrollController _scrollController = ScrollController();
  DateTime? _sessionStartTime;
  Timer? _readingTimer;
  int _sessionSeconds = 0;

  // Pagination state
  final PaginationEngine _paginationEngine = PaginationEngine();
  PaginatedChapter? _paginatedChapter;
  int _currentPage = 0;
  bool _isPaginationReady = false;

  // Structured document state (if available)
  StructuredDocument? _structuredDoc;

  // Pinch gesture state
  double _pinchStartFontSize = 0;
  bool _isPinching = false;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.startChapter;
    _controlsAnimation = AnimationController(
      duration: kFastAnimation,
      vsync: this,
    );
    _sessionStartTime = DateTime.now();
    _startReadingTimer();
  }

  void _startReadingTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
    });
  }

  @override
  void dispose() {
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
    final overallPercent = chapters.isNotEmpty
        ? (_currentChapter + 1) / chapters.length
        : 0.0;

    repo.updateProgress(progress.copyWith(
      currentChapter: _currentChapter,
      overallPercent: overallPercent.clamp(0.0, 1.0),
      chaptersCompleted: _currentChapter,
      totalReadingTimeSeconds: progress.totalReadingTimeSeconds + _sessionSeconds,
      lastReadAt: DateTime.now(),
    ));

    // Update book's lastOpened
    final book = repo.getBook(widget.bookId);
    if (book != null) {
      repo.updateBook(book.copyWith(lastOpened: DateTime.now()));
    }

    // Record session
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
      } else {
        _controlsAnimation.reverse();
      }
    });
  }

  void _goToChapter(int index) {
    final repo = ref.read(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);
    if (index >= 0 && index < chapters.length) {
      setState(() {
        _currentChapter = index;
        _currentPage = 0;
        _isPaginationReady = false;
        _paginatedChapter = null;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  void _goToPage(int page) {
    if (_paginatedChapter == null) return;
    final clampedPage = page.clamp(0, _paginatedChapter!.pageCount - 1);

    if (clampedPage != _currentPage) {
      setState(() {
        _currentPage = clampedPage;
      });
    }
  }

  void _nextPage() {
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final settings = prefsRepo.settings;
    final repo = ref.read(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);

    if (!settings.scrollMode && _paginatedChapter != null) {
      if (_currentPage < _paginatedChapter!.pageCount - 1) {
        _goToPage(_currentPage + 1);
      } else if (_currentChapter < chapters.length - 1) {
        // Go to next chapter
        _goToChapter(_currentChapter + 1);
      }
    }
  }

  void _previousPage() {
    final prefsRepo = ref.read(preferencesRepositoryProvider);
    final settings = prefsRepo.settings;

    if (!settings.scrollMode && _paginatedChapter != null) {
      if (_currentPage > 0) {
        _goToPage(_currentPage - 1);
      } else if (_currentChapter > 0) {
        // Go to last page of previous chapter
        _goToChapter(_currentChapter - 1);
        // Will need to go to last page after pagination — handled in build
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
    final repo = ref.read(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Table of Contents',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (ctx, index) {
                  final chapter = chapters[index];
                  final isCurrent = index == _currentChapter;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: isCurrent
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.surfaceContainerHigh,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isCurrent
                              ? Theme.of(ctx).colorScheme.onPrimary
                              : Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isCurrent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _goToChapter(index);
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

  void _addBookmark() {
    final repo = ref.read(bookRepositoryProvider);
    final existingBookmarks = repo.getBookmarks(widget.bookId);
    final hasBookmark = existingBookmarks.any((a) => a.chapterIndex == _currentChapter);

    if (hasBookmark) {
      final bookmark = existingBookmarks.firstWhere((a) => a.chapterIndex == _currentChapter);
      repo.removeAnnotation(bookmark.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark removed')),
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
        const SnackBar(content: Text('Bookmark added')),
      );
    }
    setState(() {});
  }

  void _lookupWord(String word) async {
    // Show the dictionary sheet immediately with loading state
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _DictionaryLookupSheet(word: word),
    );
  }


  void _onPinchStart(ReaderSettings settings) {
    _pinchStartFontSize = settings.fontSize;
    _isPinching = true;
  }

  void _onPinchUpdate(double scale, PreferencesRepository prefsRepo) {
    if (!_isPinching) return;
    final newSize = (_pinchStartFontSize * scale).clamp(kMinFontSize, kMaxFontSize);
    final settings = prefsRepo.settings;
    prefsRepo.saveSettings(settings.copyWith(fontSize: newSize));
    setState(() {
      _isPaginationReady = false;
      _paginatedChapter = null;
    });
  }

  void _onPinchEnd() {
    _isPinching = false;
  }

  // Build a structured content section for current chapter
  DocumentSection _buildStructuredSection(Chapter chapter) {
    // If structured document is available, use it
    if (_structuredDoc != null &&
        _currentChapter < _structuredDoc!.sections.length) {
      return _structuredDoc!.sections[_currentChapter];
    }

    // Otherwise, create a simple section from plain text
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
    final contentSize = Size(
      viewportSize.width - margin * 2,
      viewportSize.height - 80, // Top/bottom padding
    );

    _paginatedChapter = _paginationEngine.paginate(
      section: section,
      viewportSize: contentSize,
      settings: settings,
    );
    _isPaginationReady = true;

    // Clamp current page
    if (_paginatedChapter != null) {
      _currentPage = _currentPage.clamp(0, _paginatedChapter!.pageCount - 1);
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

    final chapter = chapters[_currentChapter.clamp(0, chapters.length - 1)];
    final readingTheme = settings.readingTheme;

    // Check if this is a PDF
    final isPdf = book.format == BookFormat.pdf;

    // Build the reading surface based on format and mode
    Widget readingSurface;
    if (isPdf) {
      readingSurface = _buildPdfReader(book, readingTheme);
    } else if (settings.scrollMode) {
      readingSurface = _buildScrollReader(chapter, settings, readingTheme, repo);
    } else {
      readingSurface = _buildPaginatedReader(chapter, settings, readingTheme, repo, chapters);
    }

    return Scaffold(
      backgroundColor: readingTheme.backgroundColor,
      body: Stack(
        children: [
          // Reading content with gestures
          GestureDetector(
            onScaleStart: !isPdf
                ? (_) => _onPinchStart(settings)
                : null,
            onScaleUpdate: !isPdf
                ? (details) {
                    if (details.pointerCount >= 2) {
                      _onPinchUpdate(details.scale, prefsRepo);
                    }
                  }
                : null,
            onScaleEnd: !isPdf
                ? (_) => _onPinchEnd()
                : null,
            child: Column(
              children: [
                // Thin progress bar
                SafeArea(
                  bottom: false,
                  child: ClipRRect(
                    child: LinearProgressIndicator(
                      value: _calculateProgress(chapters, settings),
                      minHeight: 2,
                      backgroundColor: readingTheme.surfaceColor,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                // Content
                Expanded(child: readingSurface),
              ],
            ),
          ),

          // Controls overlay
          if (_showControls) ...[
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _controlsAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () {
                                  _saveProgress();
                                  ref.read(libraryRefreshProvider.notifier).state++;
                                  Navigator.pop(context);
                                },
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      book.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      chapter.title,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  hasBookmark ? Icons.bookmark : Icons.bookmark_outline,
                                  color: Colors.white,
                                ),
                                onPressed: _addBookmark,
                              ),
                              PopupMenuButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'toc',
                                    child: ListTile(
                                      leading: Icon(Icons.list),
                                      title: Text('Table of Contents'),
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'settings',
                                    child: ListTile(
                                      leading: Icon(Icons.text_format),
                                      title: Text('Reader Settings'),
                                      dense: true,
                                    ),
                                  ),
                                  if (!isPdf)
                                    const PopupMenuItem(
                                      value: 'rsvp',
                                      child: ListTile(
                                        leading: Icon(Icons.speed),
                                        title: Text('RSVP Mode'),
                                        dense: true,
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: ListTile(
                                      leading: Icon(Icons.info_outline),
                                      title: Text('Book Details'),
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
                                      Navigator.pushNamed(context, '/book-details',
                                          arguments: widget.bookId);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _controlsAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _controlsAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Chapter/page slider
                              Row(
                                children: [
                                  Text(
                                    _getPositionLabel(settings, chapters),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
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
                                  Text(
                                    _getMaxLabel(settings, chapters),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              // Navigation buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                                    onPressed: _currentChapter > 0
                                        ? () => _goToChapter(_currentChapter - 1)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.list, color: Colors.white),
                                    onPressed: _showTableOfContents,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.text_format, color: Colors.white),
                                    onPressed: _showReaderSettings,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next, color: Colors.white),
                                    onPressed: _currentChapter < chapters.length - 1
                                        ? () => _goToChapter(_currentChapter + 1)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
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
        final page = _paginatedChapter!.pages[_currentPage.clamp(0, totalPages - 1)];

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final screenWidth = constraints.maxWidth;
            final tapX = details.localPosition.dx;
            final tapY = details.localPosition.dy;
            final screenHeight = constraints.maxHeight;

            // Center third detection
            final leftThird = screenWidth / 3;
            final rightThird = screenWidth * 2 / 3;
            final topThird = screenHeight / 3;
            final bottomThird = screenHeight * 2 / 3;

            if (tapX > leftThird && tapX < rightThird &&
                tapY > topThird && tapY < bottomThird) {
              // Center tap — toggle controls
              _toggleControls();
            } else if (tapX < leftThird) {
              // Left tap — previous page
              _previousPage();
            } else if (tapX > rightThird) {
              // Right tap — next page
              _nextPage();
            }
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -200) {
              _nextPage();
            } else if (velocity > 200) {
              _previousPage();
            }
          },
          child: Container(
            color: readingTheme.backgroundColor,
            padding: EdgeInsets.symmetric(
              horizontal: settings.margin,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Page content
                Expanded(
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
                // Page indicator
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Page ${_currentPage + 1} of $totalPages  •  Chapter ${_currentChapter + 1} of ${chapters.length}',
                      style: TextStyle(
                        color: readingTheme.textColor.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

    return GestureDetector(
      onTapUp: (details) {
        final size = MediaQuery.of(context).size;
        final tapX = details.globalPosition.dx;
        final tapY = details.globalPosition.dy;
        final centerX = size.width / 2;
        final centerY = size.height / 2;

        // Center third of screen
        if ((tapX - centerX).abs() < size.width / 6 &&
            (tapY - centerY).abs() < size.height / 6) {
          _toggleControls();
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: settings.margin,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            // Chapter title
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
            // Chapter content — structured blocks
            ContentBlockRenderer(
              blocks: section.contentBlocks,
              settings: settings,
              readingTheme: readingTheme,
              images: _structuredDoc?.images ?? const {},
              onWordLookup: _lookupWord,
            ),
            SizedBox(height: settings.paragraphSpacing * 2),
            // Chapter navigation at bottom
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
      // Combined chapter + page progress
      final chapterFraction = 1.0 / chapters.length;
      final pageFraction = (_currentPage + 1) / _paginatedChapter!.pageCount;
      return (_currentChapter * chapterFraction + pageFraction * chapterFraction).clamp(0.0, 1.0);
    }
    return ((_currentChapter + 1) / chapters.length).clamp(0.0, 1.0);
  }

  String _getPositionLabel(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      return 'Page ${_currentPage + 1}';
    }
    return 'Ch. ${_currentChapter + 1}';
  }

  String _getMaxLabel(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      return 'Page ${_paginatedChapter!.pageCount}';
    }
    return 'Ch. ${chapters.length}';
  }

  double _getSliderValue(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      return _currentPage.toDouble();
    }
    return _currentChapter.toDouble();
  }

  double _getSliderMax(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      return (_paginatedChapter!.pageCount - 1).toDouble().clamp(0, double.infinity);
    }
    return (chapters.length - 1).toDouble();
  }

  int? _getSliderDivisions(ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      return _paginatedChapter!.pageCount > 1 ? _paginatedChapter!.pageCount - 1 : 1;
    }
    return chapters.length > 1 ? chapters.length - 1 : 1;
  }

  void _onSliderChanged(double value, ReaderSettings settings, List<Chapter> chapters) {
    if (!settings.scrollMode && _paginatedChapter != null) {
      _goToPage(value.toInt());
    } else {
      _goToChapter(value.toInt());
    }
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
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
