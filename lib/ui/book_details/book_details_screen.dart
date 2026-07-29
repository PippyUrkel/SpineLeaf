import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/ai_summary_service.dart';
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
  final Map<int, ChapterSummary> _summaries = {};
  bool _generatingSummary = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _BookHeader(book: book, progress: progress),
            ),
            actions: [
              PopupMenuButton(
                itemBuilder: (context) => [
                  if (book.status != BookStatus.completed)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark as Completed'),
                    ),
                  if (book.status != BookStatus.unread)
                    const PopupMenuItem(
                      value: 'unread',
                      child: Text('Mark as Unread'),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'complete') {
                    repo.setBookStatus(widget.bookId, BookStatus.completed);
                  } else if (value == 'unread') {
                    repo.setBookStatus(widget.bookId, BookStatus.unread);
                  }
                  setState(() {});
                },
              ),
            ],
          ),
          // Action buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/reader', arguments: {
                          'bookId': widget.bookId,
                          'startChapter': progress.currentChapter,
                        });
                      },
                      icon: Icon(
                        progress.overallPercent > 0
                            ? Icons.play_arrow
                            : Icons.menu_book,
                      ),
                      label: Text(
                        progress.overallPercent > 0 ? 'Continue' : 'Start Reading',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/rsvp', arguments: {
                        'bookId': widget.bookId,
                        'chapterIndex': progress.currentChapter,
                      });
                    },
                    icon: const Icon(Icons.speed),
                    label: const Text('RSVP'),
                  ),
                ],
              ),
            ),
          ),
          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Chapters (${chapters.length})'),
                  Tab(text: 'Bookmarks (${bookmarks.length})'),
                  Tab(text: 'Highlights (${highlights.length})'),
                  Tab(text: 'Notes (${notes.length})'),
                  const Tab(text: 'AI Summary'),
                ],
              ),
              context,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Chapters
            _ChapterList(
              chapters: chapters,
              progress: progress,
              bookId: widget.bookId,
            ),
            // Bookmarks
            _AnnotationList(
              annotations: bookmarks,
              emptyIcon: Icons.bookmark_outline,
              emptyText: 'No bookmarks yet',
              bookId: widget.bookId,
            ),
            // Highlights
            _AnnotationList(
              annotations: highlights,
              emptyIcon: Icons.highlight_outlined,
              emptyText: 'No highlights yet',
              bookId: widget.bookId,
            ),
            // Notes
            _AnnotationList(
              annotations: notes,
              emptyIcon: Icons.note_outlined,
              emptyText: 'No notes yet',
              bookId: widget.bookId,
            ),
            // AI Summary
            _AiSummaryTab(
              bookId: widget.bookId,
              chapters: chapters,
              progress: progress,
              summaries: _summaries,
              isGenerating: _generatingSummary,
              onGenerate: (index) => _generateSummary(index, chapters),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSummary(int chapterIndex, List<Chapter> chapters) async {
    if (_generatingSummary) return;
    setState(() => _generatingSummary = true);

    final aiService = ref.read(aiSummaryServiceProvider);
    final chapter = chapters[chapterIndex];

    final summary = await aiService.generateSummary(
      widget.bookId,
      chapterIndex,
      chapter.title,
      chapter.content,
    );

    setState(() {
      _summaries[chapterIndex] = summary;
      _generatingSummary = false;
    });
  }
}

class _BookHeader extends StatelessWidget {
  final Book book;
  final ReadingProgress progress;

  const _BookHeader({required this.book, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.colorScheme.primaryContainer,
            context.colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BookCoverWidget(
                title: book.title,
                author: book.author,
                bookId: book.id,
                width: 100,
                height: 150,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (book.publisher != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.publisher!,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Progress
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.overallPercent,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          progress.overallPercent.asPercent,
                          style: context.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.totalChapters} chapters • ${book.status.label} • ${progress.totalReadingTime.formatted}',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (book.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        book.description!,
                        style: context.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterList extends StatelessWidget {
  final List<Chapter> chapters;
  final ReadingProgress progress;
  final String bookId;

  const _ChapterList({
    required this.chapters,
    required this.progress,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final isCompleted = progress.isChapterRead(index);
        final isCurrent = index == progress.currentChapter;

        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: isCompleted
                ? context.colorScheme.primary
                : isCurrent
                    ? context.colorScheme.primaryContainer
                    : context.colorScheme.surfaceContainerHigh,
            child: isCompleted
                ? Icon(Icons.check, size: 16, color: context.colorScheme.onPrimary)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? context.colorScheme.onPrimaryContainer
                          : context.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          title: Text(
            chapter.title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Text('${chapter.wordCount} words'),
          trailing: isCurrent
              ? Chip(
                  label: const Text('Current'),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 11),
                )
              : null,
          onTap: () {
            Navigator.pushNamed(context, '/reader', arguments: {
              'bookId': bookId,
              'startChapter': index,
            });
          },
        );
      },
    );
  }
}

class _AnnotationList extends StatelessWidget {
  final List<Annotation> annotations;
  final IconData emptyIcon;
  final String emptyText;
  final String bookId;

  const _AnnotationList({
    required this.annotations,
    required this.emptyIcon,
    required this.emptyText,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 48, color: context.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              emptyText,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: annotations.length,
      itemBuilder: (context, index) {
        final annotation = annotations[index];

        return ListTile(
          leading: Icon(
            annotation.type == AnnotationType.bookmark
                ? Icons.bookmark
                : annotation.type == AnnotationType.highlight
                    ? Icons.highlight
                    : Icons.note,
            color: annotation.highlightColor ?? context.colorScheme.primary,
          ),
          title: Text(
            annotation.selectedText ?? 'Chapter ${annotation.chapterIndex + 1}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (annotation.note != null)
                Text(
                  annotation.note!,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                'Ch. ${annotation.chapterIndex + 1} • ${annotation.createdAt.relativeTime}',
                style: context.textTheme.labelSmall,
              ),
            ],
          ),
          onTap: () {
            Navigator.pushNamed(context, '/reader', arguments: {
              'bookId': bookId,
              'startChapter': annotation.chapterIndex,
            });
          },
        );
      },
    );
  }
}

class _AiSummaryTab extends StatelessWidget {
  final String bookId;
  final List<Chapter> chapters;
  final ReadingProgress progress;
  final Map<int, ChapterSummary> summaries;
  final bool isGenerating;
  final Function(int) onGenerate;

  const _AiSummaryTab({
    required this.bookId,
    required this.chapters,
    required this.progress,
    required this.summaries,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    // Only show chapters the user has read
    final readChapters = chapters.where((c) => progress.isChapterRead(c.index)).toList();

    if (readChapters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 48, color: context.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'AI Summaries',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Start reading to unlock AI-generated chapter summaries. '
                'Only chapters you\'ve already read will be summarized to avoid spoilers.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: readChapters.length,
      itemBuilder: (context, index) {
        final chapter = readChapters[index];
        final summary = summaries[chapter.index];

        if (summary == null) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ch. ${chapter.index + 1}: ${chapter.title}',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: isGenerating ? null : () => onGenerate(chapter.index),
                      icon: isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(isGenerating ? 'Generating...' : 'Generate Summary'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: context.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ch. ${chapter.index + 1}: ${chapter.title}',
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(summary.summary, style: context.textTheme.bodyMedium),
                if (summary.keyPoints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Key Points', style: context.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  ...summary.keyPoints.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: context.colorScheme.primary)),
                        Expanded(child: Text(point, style: context.textTheme.bodySmall)),
                      ],
                    ),
                  )),
                ],
                if (summary.characters.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: summary.characters.map((name) => Chip(
                      avatar: const Icon(Icons.person, size: 14),
                      label: Text(name),
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 11),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final BuildContext context;

  _SliverTabBarDelegate(this.tabBar, this.context);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
