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

    // Automatically include the current chapter in readChapterIndices
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
      _saveProgress();
      setState(() {
        _currentChapter = index;
        _currentPage = 0;
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
    final clampedPage = page.clamp(0, _paginatedChapter!.pageCount - 1);

    if (clampedPage != _currentPage) {
      setState(() {
        _currentPage = clampedPage;
      });
      _saveProgress();
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

        // If _currentPage >= totalPages, render Interstitial Black Filler Page!
        if (_currentPage >= totalPages) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) {
              final screenWidth = constraints.maxWidth;
              final tapX = details.localPosition.dx;
              final leftThird = screenWidth / 3;
              final rightThird = screenWidth * 2 / 3;

              if (tapX < leftThird) {
                _previousPage();
              } else if (tapX > rightThird) {
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
            child: _buildInterstitialPage(chapters, readingTheme),
          );
        }

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

  // ─── Interstitial Chapter Transition Page ────────────────────────────

  Widget _buildInterstitialPage(List<Chapter> chapters, ReadingTheme readingTheme) {
    final currentChapterObj = chapters[_currentChapter.clamp(0, chapters.length - 1)];
    final hasNext = _currentChapter < chapters.length - 1;
    final nextChapterObj = hasNext ? chapters[_currentChapter + 1] : null;

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CHAPTER COMPLETE',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentChapterObj.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              Divider(color: Colors.white.withValues(alpha: 0.2), indent: 40, endIndent: 40),
              const SizedBox(height: 28),
              if (hasNext && nextChapterObj != null) ...[
                Text(
                  'UP NEXT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chapter ${_currentChapter + 2}: ${nextChapterObj.title}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _goToChapter(_currentChapter + 1),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Start Next Chapter'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ] else ...[
                const Text(
                  '🎉 Congratulations!',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have completed this entire book.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
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
            // Drag handle
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
            // Header
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

            // Chapters list
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (ctx, index) {
                  final chapter = chapters[index];
                  final isCurrent = index == widget.currentChapter;
                  final isRead = progress.isChapterRead(index);
                  final isSelected = _selectedIndices.contains(index);

                  // Read chapters are greyed out
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
                    subtitle: Text(
                      '${chapter.wordCount} words',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: isRead ? 0.35 : 0.6),
                      ),
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
