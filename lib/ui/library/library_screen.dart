import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/import_service.dart';
import '../widgets/book_cover.dart';

// Library state providers
final librarySortProvider = StateProvider<LibrarySort>((ref) => LibrarySort.recentlyRead);
final libraryFilterProvider = StateProvider<BookStatus?>((ref) => null);
final librarySearchProvider = StateProvider<String>((ref) => '');
final libraryViewModeProvider = StateProvider<bool>((ref) => true); // true = grid, false = list
final libraryGridColumnsProvider = StateProvider<int>((ref) => 2); // 2, 3, 4, 5 columns
final libraryRefreshProvider = StateProvider<int>((ref) => 0);

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookRepositoryProvider);
    final sort = ref.watch(librarySortProvider);
    final filter = ref.watch(libraryFilterProvider);
    final search = ref.watch(librarySearchProvider);
    final isGrid = ref.watch(libraryViewModeProvider);
    final gridColumns = ref.watch(libraryGridColumnsProvider);
    ref.watch(libraryRefreshProvider); // triggers rebuild

    final books = repo.getBooksWithProgress(
      sort: sort,
      filterStatus: filter,
      searchQuery: search.isEmpty ? null : search,
    );
    final continueReading = repo.getMostRecentlyRead();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          // Explicit View Switcher Menu (Grid vs List)
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.grid_view, size: 18),
                tooltip: 'Grid View',
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.view_list, size: 18),
                tooltip: 'List View',
              ),
            ],
            selected: {isGrid},
            onSelectionChanged: (Set<bool> selection) {
              ref.read(libraryViewModeProvider.notifier).state = selection.first;
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          // Grid Columns Dropdown Menu (when grid view is active)
          if (isGrid)
            PopupMenuButton<int>(
              icon: const Icon(Icons.view_column_outlined),
              tooltip: 'Grid Columns',
              initialValue: gridColumns,
              onSelected: (value) {
                ref.read(libraryGridColumnsProvider.notifier).state = value;
              },
              itemBuilder: (context) => [2, 3, 4, 5].map((cols) {
                return PopupMenuItem<int>(
                  value: cols,
                  child: Row(
                    children: [
                      if (cols == gridColumns) ...[
                        Icon(Icons.check, size: 18, color: context.colorScheme.primary),
                        const SizedBox(width: 8),
                      ],
                      Text('$cols Columns'),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(width: 4),
          // Sort menu
          PopupMenuButton<LibrarySort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (value) {
              ref.read(librarySortProvider.notifier).state = value;
            },
            itemBuilder: (context) => LibrarySort.values.map((s) {
              return PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    if (s == sort) ...[
                      Icon(Icons.check, size: 18, color: context.colorScheme.primary),
                      const SizedBox(width: 8),
                    ],
                    Text(s.label),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search bar
          // SliverToBoxAdapter(
          //   child: Padding(
          //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          //     child: SearchBar(
          //       hintText: 'Search books...',
          //       leading: const Padding(
          //         padding: EdgeInsets.only(left: 8),
          //         child: Icon(Icons.search),
          //       ),
          //       trailing: search.isNotEmpty
          //           ? [
          //               IconButton(
          //                 icon: const Icon(Icons.close),
          //                 onPressed: () {
          //                   ref.read(librarySearchProvider.notifier).state = '';
          //                 },
          //               ),
          //             ]
          //           : null,
          //       onChanged: (value) {
          //         ref.read(librarySearchProvider.notifier).state = value;
          //       },
          //       elevation: const WidgetStatePropertyAll(0),
          //       backgroundColor: WidgetStatePropertyAll(
          //         context.colorScheme.surfaceContainerHigh,
          //       ),
          //     ),
          //   ),
          // ),

          // Filter chips
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _FilterChipWidget(
                    label: 'All',
                    selected: filter == null,
                    onSelected: () {
                      ref.read(libraryFilterProvider.notifier).state = null;
                    },
                  ),
                  const SizedBox(width: 8),
                  ...BookStatus.values.map((status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChipWidget(
                      label: status.label,
                      selected: filter == status,
                      onSelected: () {
                        ref.read(libraryFilterProvider.notifier).state = status;
                      },
                    ),
                  )),
                ],
              ),
            ),
          ),

          // Continue Reading section
          if (continueReading != null && search.isEmpty && filter == null)
            SliverToBoxAdapter(
              child: _ContinueReadingCard(bookWithProgress: continueReading),
            ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    filter != null ? filter.label : 'Your Library',
                    style: context.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${books.length} books',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          // Book list / grid
          if (books.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_books_outlined,
                      size: 64,
                      color: context.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      search.isNotEmpty ? 'No books found' : 'Your library is empty',
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to import a book',
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else if (isGrid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _BookGridCard(
                    bookWithProgress: books[index],
                    onRefresh: () => ref.read(libraryRefreshProvider.notifier).state++,
                  ),
                  childCount: books.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  childAspectRatio: gridColumns >= 5 ? 0.42 : (gridColumns == 4 ? 0.46 : (gridColumns == 3 ? 0.50 : 0.55)),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _BookListTile(
                    bookWithProgress: books[index],
                    onRefresh: () => ref.read(libraryRefreshProvider.notifier).state++,
                  ),
                  childCount: books.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImportDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Import'),
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.file_upload_outlined),
        title: const Text('Import Book'),
        content: const Text(
          'Import e-books from your device storage.\n\n'
          'Supported formats: EPUB, PDF, RTF, TXT, Markdown',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(importServiceProvider).importBook();
                ref.read(libraryRefreshProvider.notifier).state++;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Book imported successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error importing book: $e')),
                  );
                }
              }
            },
            child: const Text('Browse Files'),
          ),
        ],
      ),
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChipWidget({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

class _ContinueReadingCard extends ConsumerWidget {
  final BookWithProgress bookWithProgress;

  const _ContinueReadingCard({required this.bookWithProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = bookWithProgress.book;
    final progress = bookWithProgress.progress;
    final repo = ref.watch(bookRepositoryProvider);
    final chapters = repo.getChapters(book.id);
    final currentChapterIndex = progress?.currentChapter ?? 0;
    final currentChapter = chapters.isNotEmpty
        ? chapters[currentChapterIndex.clamp(0, chapters.length - 1)]
        : null;

    return Card(
      elevation: 0,
      color: context.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(context, '/reader', arguments: {
            'bookId': book.id,
            'startChapter': progress?.currentChapter ?? 0,
            'startPage': progress?.positionInChapter.toInt() ?? 0,
          }).then((_) {
            ref.read(libraryRefreshProvider.notifier).state++;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Book cover thumbnail
              BookCoverWidget(
                title: book.title,
                author: book.author,
                bookId: book.id,
                coverPath: book.coverPath,
                progress: bookWithProgress.progressPercent,
                width: 56,
                height: 84,
              ),
              const SizedBox(width: 14),

              // Info & Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CONTINUE READING',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (currentChapter != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ch. ${currentChapter.index + 1}: ${currentChapter.title}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: bookWithProgress.progressPercent,
                              minHeight: 5,
                              backgroundColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bookWithProgress.progressPercent.asPercent,
                          style: context.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.colorScheme.primary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Minimal Action Icon
              FilledButton.tonal(
                onPressed: () {
                  Navigator.pushNamed(context, '/reader', arguments: {
                    'bookId': book.id,
                    'startChapter': progress?.currentChapter ?? 0,
                    'startPage': progress?.positionInChapter.toInt() ?? 0,
                  }).then((_) {
                    ref.read(libraryRefreshProvider.notifier).state++;
                  });
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookGridCard extends StatelessWidget {
  final BookWithProgress bookWithProgress;
  final VoidCallback onRefresh;

  const _BookGridCard({required this.bookWithProgress, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final book = bookWithProgress.book;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/book-details', arguments: book.id).then((_) => onRefresh());
      },
      onLongPress: () => _showContextMenu(context, book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover with wavy liquid progress fill directly on cover
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 0.67,
                    child: BookCoverWidget(
                      title: book.title,
                      author: book.author,
                      bookId: book.id,
                      coverPath: book.coverPath,
                      progress: bookWithProgress.progressPercent,
                      width: double.infinity,
                    ),
                  ),
                ),
                // Status badge
                if (book.status == BookStatus.completed)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '✓',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            book.title,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Author
          Text(
            book.author,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _BookActionsSheet(book: book, onRefresh: onRefresh),
    );
  }
}

class _BookListTile extends StatelessWidget {
  final BookWithProgress bookWithProgress;
  final VoidCallback onRefresh;

  const _BookListTile({required this.bookWithProgress, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final book = bookWithProgress.book;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(context, '/book-details', arguments: book.id).then((_) => onRefresh());
        },
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => _BookActionsSheet(book: book, onRefresh: onRefresh),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BookCoverWidget(
                title: book.title,
                author: book.author,
                bookId: book.id,
                coverPath: book.coverPath,
                progress: bookWithProgress.progressPercent,
                width: 56,
                height: 84,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: context.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      book.author,
                      style: context.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${bookWithProgress.progressPercent.asPercent} • ${book.totalChapters} chapters',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bookWithProgress.progress?.lastReadAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        bookWithProgress.progress!.lastReadAt!.relativeTime,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => _BookActionsSheet(book: book, onRefresh: onRefresh),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookActionsSheet extends ConsumerWidget {
  final Book book;
  final VoidCallback onRefresh;

  const _BookActionsSheet({required this.book, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: context.textTheme.titleMedium),
                      Text(book.author, style: context.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Read'),
            onTap: () {
              Navigator.pop(context);
              final progress = ref.read(bookRepositoryProvider).getProgress(book.id);
              Navigator.pushNamed(context, '/reader', arguments: {
                'bookId': book.id,
                'startChapter': progress.currentChapter,
                'startPage': progress.positionInChapter.toInt(),
              }).then((_) => onRefresh());
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Book Details'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/book-details', arguments: book.id).then((_) => onRefresh());
            },
          ),
          if (book.status != BookStatus.completed)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as Completed'),
              onTap: () {
                ref.read(bookRepositoryProvider).setBookStatus(book.id, BookStatus.completed);
                onRefresh();
                Navigator.pop(context);
              },
            ),
          if (book.status != BookStatus.unread)
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('Mark as Unread'),
              onTap: () {
                ref.read(bookRepositoryProvider).setBookStatus(book.id, BookStatus.unread);
                onRefresh();
                Navigator.pop(context);
              },
            ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: context.colorScheme.error),
            title: Text('Remove', style: TextStyle(color: context.colorScheme.error)),
            onTap: () {
              ref.read(bookRepositoryProvider).removeBook(book.id);
              onRefresh();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
