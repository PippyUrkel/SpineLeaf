import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../data/repositories/repositories.dart';
import '../widgets/book_cover.dart';

class BookDetailsScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailsScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends ConsumerState<BookDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSelectionMode = false;
  final Set<int> _selectedChapterIndices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleChapterSelection(int index) {
    setState(() {
      if (_selectedChapterIndices.contains(index)) {
        _selectedChapterIndices.remove(index);
        if (_selectedChapterIndices.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChapterIndices.add(index);
      }
    });
  }

  void _startSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedChapterIndices.add(index);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedChapterIndices.clear();
      _isSelectionMode = false;
    });
  }

  void _selectAll(int totalChapters) {
    setState(() {
      _selectedChapterIndices.addAll(List.generate(totalChapters, (i) => i));
    });
  }

  void _batchMarkRead() {
    final repo = ref.read(bookRepositoryProvider);
    repo.markChaptersRead(widget.bookId, _selectedChapterIndices);
    _clearSelection();
  }

  void _batchMarkUnread() {
    final repo = ref.read(bookRepositoryProvider);
    repo.markChaptersUnread(widget.bookId, _selectedChapterIndices);
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(bookRepositoryProvider);
    final book = repo.getBook(widget.bookId);
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Book not found')),
      );
    }

    final progress = repo.getProgress(widget.bookId);
    final chapters = repo.getChapters(widget.bookId);
    final bookmarks = repo.getBookmarks(widget.bookId);
    final highlights = repo.getHighlights(widget.bookId);
    final notes = repo.getNotes(widget.bookId);
    final allAnnotations = [...bookmarks, ...highlights, ...notes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final hasStarted = progress.overallPercent > 0;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      // Floating "▶ Resume" action button (hidden in selection mode)
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, '/reader', arguments: {
                  'bookId': widget.bookId,
                  'startChapter': progress.currentChapter,
                  'startPage': progress.positionInChapter.toInt(),
                }).then((_) => setState(() {}));
              },
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              elevation: 4,
              icon: Icon(hasStarted ? Icons.play_arrow_rounded : Icons.menu_book_rounded),
              label: Text(
                hasStarted ? 'Resume' : 'Start',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),

      // Bottom Batch Selection Bar (Matching second screenshot)
      bottomNavigationBar: _isSelectionMode
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.done_all),
                      tooltip: 'Mark Selected as Read',
                      onPressed: _selectedChapterIndices.isNotEmpty ? _batchMarkRead : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_done),
                      tooltip: 'Mark Selected as Unread',
                      onPressed: _selectedChapterIndices.isNotEmpty ? _batchMarkUnread : null,
                    ),
                    IconButton(
                      icon: Icon(
                        _selectedChapterIndices.length == chapters.length
                            ? Icons.deselect
                            : Icons.select_all,
                      ),
                      tooltip: _selectedChapterIndices.length == chapters.length
                          ? 'Deselect All'
                          : 'Select All',
                      onPressed: () {
                        if (_selectedChapterIndices.length == chapters.length) {
                          _clearSelection();
                        } else {
                          _selectAll(chapters.length);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel Selection',
                      onPressed: _clearSelection,
                    ),
                  ],
                ),
              ),
            )
          : null,

      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // Sleek Darkened Multiplied Gradient Header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            title: _isSelectionMode
                ? Text('${_selectedChapterIndices.length} selected')
                : null,
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Darkened Multiplied Cover Image Backdrop (Matching photo)
                  if (book.coverPath != null)
                    Image.asset(
                      book.coverPath!,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.75),
                      colorBlendMode: BlendMode.multiply,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          theme.colorScheme.surface.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),

                  // Header Info Row
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Borderless Cover Thumbnail
                          Hero(
                            tag: 'cover_${book.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: BookCoverWidget(
                                title: book.title,
                                author: book.author,
                                bookId: book.id,
                                coverPath: book.coverPath,
                                progress: progress.overallPercent,
                                width: 84,
                                height: 126,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Title, Author, Metadata
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                    height: 1.25,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        book.author,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      size: 13,
                                      color: Colors.white60,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${book.format.label} • ${book.status.label}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!_isSelectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    if (book.status != BookStatus.completed)
                      const PopupMenuItem(
                        value: 'complete',
                        child: ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('Mark as Completed'),
                          dense: true,
                        ),
                      ),
                    if (book.status != BookStatus.unread)
                      const PopupMenuItem(
                        value: 'unread',
                        child: ListTile(
                          leading: Icon(Icons.refresh),
                          title: Text('Mark as Unread'),
                          dense: true,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'rsvp',
                      child: ListTile(
                        leading: Icon(Icons.speed),
                        title: Text('RSVP Speed Reading'),
                        dense: true,
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'complete') {
                      repo.setBookStatus(widget.bookId, BookStatus.completed);
                    } else if (value == 'unread') {
                      repo.setBookStatus(widget.bookId, BookStatus.unread);
                    } else if (value == 'rsvp') {
                      Navigator.pushNamed(context, '/rsvp', arguments: {
                        'bookId': widget.bookId,
                        'chapterIndex': progress.currentChapter,
                      });
                    }
                    setState(() {});
                  },
                ),
            ],
          ),

          // Sub-Header Quick Action Bar
          if (!_isSelectionMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuickActionButton(
                      icon: book.status != BookStatus.unread ? Icons.favorite : Icons.favorite_border,
                      label: 'In library',
                      isActive: book.status != BookStatus.unread,
                      onTap: () {
                        final newStatus = book.status != BookStatus.unread ? BookStatus.unread : BookStatus.reading;
                        repo.setBookStatus(widget.bookId, newStatus);
                        setState(() {});
                      },
                    ),
                    _QuickActionButton(
                      icon: Icons.speed_rounded,
                      label: 'RSVP',
                      onTap: () {
                        Navigator.pushNamed(context, '/rsvp', arguments: {
                          'bookId': widget.bookId,
                          'chapterIndex': progress.currentChapter,
                        });
                      },
                    ),
                    _QuickActionButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Summary',
                      onTap: () {
                        _tabController.animateTo(1);
                      },
                    ),
                    _QuickActionButton(
                      icon: Icons.bookmark_outline_rounded,
                      label: 'Notes (${allAnnotations.length})',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

          // Minimal Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    book.format == BookFormat.pdf ? 'Document' : '${chapters.length} chapters',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  if (progress.overallPercent > 0)
                    Text(
                      '${progress.overallPercent.asPercent} read',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        // Chapter List with Long Press Batch Selection Mode
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            final isCompleted = progress.isChapterRead(index);
            final isCurrent = index == progress.currentChapter;
            final isSelected = _selectedChapterIndices.contains(index);

            return ListTile(
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: _isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleChapterSelection(index),
                    )
                  : Icon(
                      Icons.circle,
                      size: 8,
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : isCompleted
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
              title: Text(
                book.format == BookFormat.pdf ? 'Full Document' : 'Chapter ${index + 1}: ${chapter.title}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCompleted
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: isCurrent && progress.positionInChapter > 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${(progress.positionInChapter * 100).round()}% completed',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
              trailing: _isSelectionMode
                  ? null
                  : isCompleted
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        )
                      : isCurrent
                          ? Icon(
                              Icons.play_circle_fill_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            )
                          : null,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleChapterSelection(index);
                } else {
                  Navigator.pushNamed(context, '/reader', arguments: {
                    'bookId': widget.bookId,
                    'startChapter': index,
                  }).then((_) => setState(() {}));
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _startSelectionMode(index);
                } else {
                  _toggleChapterSelection(index);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Minimal Action Icon Button ────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
