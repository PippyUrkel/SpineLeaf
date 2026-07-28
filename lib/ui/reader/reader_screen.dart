import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/dictionary_service.dart';
import '../library/library_screen.dart';

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
        _scrollController.jumpTo(0);
      });
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
          setState(() {});
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
    final dictService = ref.read(dictionaryServiceProvider);
    final entry = await dictService.define(word);
    if (entry != null && mounted) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => _DictionarySheet(entry: entry),
      );
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

    return Scaffold(
      backgroundColor: readingTheme.backgroundColor,
      body: Stack(
        children: [
          // Reading content
          GestureDetector(
            onTap: _toggleControls,
            child: Column(
              children: [
                // Thin progress bar
                SafeArea(
                  bottom: false,
                  child: ClipRRect(
                    child: LinearProgressIndicator(
                      value: ((_currentChapter + 1) / chapters.length).clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: readingTheme.surfaceColor,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                // Content
                Expanded(
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
                        // Chapter content
                        SelectableText(
                          chapter.content,
                          style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontSize: settings.fontSize,
                            fontWeight: settings.fontWeight,
                            height: settings.lineHeight,
                            color: readingTheme.textColor,
                            letterSpacing: 0.2,
                          ),
                          textAlign: settings.textAlign.value,
                          onSelectionChanged: (selection, cause) {
                            // Text selection handling - could add floating menu
                          },
                          contextMenuBuilder: (context, editableTextState) {
                            final selection = editableTextState.textEditingValue.selection;
                            final text = editableTextState.textEditingValue.text;
                            final selectedText = selection.textInside(text).trim();

                            return AdaptiveTextSelectionToolbar(
                              anchors: editableTextState.contextMenuAnchors,
                              children: [
                                if (selectedText.isNotEmpty && selectedText.split(' ').length <= 3)
                                  _ToolbarButton(
                                    icon: Icons.book,
                                    label: 'Define',
                                    onPressed: () {
                                      editableTextState.hideToolbar();
                                      _lookupWord(selectedText);
                                    },
                                  ),
                                if (selectedText.isNotEmpty)
                                  _ToolbarButton(
                                    icon: Icons.highlight,
                                    label: 'Highlight',
                                    onPressed: () {
                                      editableTextState.hideToolbar();
                                      repo.addAnnotation(Annotation(
                                        id: 'hl_${DateTime.now().millisecondsSinceEpoch}',
                                        bookId: widget.bookId,
                                        chapterIndex: _currentChapter,
                                        type: AnnotationType.highlight,
                                        selectedText: selectedText,
                                        highlightColor: kHighlightColors[0],
                                        position: selection.start,
                                        createdAt: DateTime.now(),
                                      ));
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(content: Text('Highlighted')),
                                      );
                                    },
                                  ),
                                if (selectedText.isNotEmpty)
                                  _ToolbarButton(
                                    icon: Icons.note_add,
                                    label: 'Note',
                                    onPressed: () {
                                      editableTextState.hideToolbar();
                                      _showAddNoteDialog(selectedText);
                                    },
                                  ),
                                _ToolbarButton(
                                  icon: Icons.copy,
                                  label: 'Copy',
                                  onPressed: () {
                                    editableTextState.copySelection(SelectionChangedCause.toolbar);
                                  },
                                ),
                              ],
                            );
                          },
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
                ),
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
                              // Chapter slider
                              Row(
                                children: [
                                  Text(
                                    'Ch. ${_currentChapter + 1}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _currentChapter.toDouble(),
                                      min: 0,
                                      max: (chapters.length - 1).toDouble(),
                                      divisions: chapters.length > 1 ? chapters.length - 1 : 1,
                                      onChanged: (value) {
                                        _goToChapter(value.toInt());
                                      },
                                    ),
                                  ),
                                  Text(
                                    'Ch. ${chapters.length}',
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

  void _showAddNoteDialog(String selectedText) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$selectedText"',
              style: const TextStyle(fontStyle: FontStyle.italic),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Your note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final repo = ref.read(bookRepositoryProvider);
              repo.addAnnotation(Annotation(
                id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                bookId: widget.bookId,
                chapterIndex: _currentChapter,
                type: AnnotationType.note,
                selectedText: selectedText,
                note: controller.text,
                position: 0,
                createdAt: DateTime.now(),
              ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note added')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
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

// ─── Dictionary Bottom Sheet ──────────────────────────────────────────

class _DictionarySheet extends StatelessWidget {
  final DictionaryEntry entry;

  const _DictionarySheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  entry.word,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (entry.pronunciation != null) ...[
              Text(
                entry.pronunciation!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...entry.definitions.map((def) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        def.partOfSpeech,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(def.definition, style: Theme.of(context).textTheme.bodyMedium),
                    if (def.example != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${def.example}"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
