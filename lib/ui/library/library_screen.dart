import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/import_service.dart';
import '../widgets/book_cover.dart';
import '../widgets/soda_progress.dart';

// Library state providers
final librarySortProvider = StateProvider<LibrarySort>((ref) => LibrarySort.recentlyRead);
final libraryFilterProvider = StateProvider<BookStatus?>((ref) => null);
final librarySearchProvider = StateProvider<String>((ref) => '');
final libraryViewModeProvider = StateProvider<bool>((ref) => true); // true = grid
final libraryGridColumnsProvider = StateProvider<int>((ref) => 2); // 2 to 5 columns
final libraryRefreshProvider = StateProvider<int>((ref) => 0);

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _initialColsOnScale = 2;

  void _onScaleStart(ScaleStartDetails details) {
    _initialColsOnScale = ref.read(libraryGridColumnsProvider);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;

    // Pinch in (scale < 1.0) -> shrink elements -> INCREASE column count (up to max 5 cols)
    // Pinch out (scale > 1.0) -> enlarge elements -> DECREASE column count (down to min 2 cols)
    final scaleDelta = details.scale - 1.0;
    if (scaleDelta.abs() > 0.15) {
      int newCols = _initialColsOnScale;
      if (scaleDelta < -0.15) {
        // Pinching in: add columns
        newCols = (_initialColsOnScale + (scaleDelta.abs() * 3).round()).clamp(2, 5);
      } else if (scaleDelta > 0.15) {
        // Pinching out: subtract columns
        newCols = (_initialColsOnScale - (scaleDelta * 3).round()).clamp(2, 5);
      }

      if (newCols != ref.read(libraryGridColumnsProvider)) {
        ref.read(libraryGridColumnsProvider.notifier).state = newCols;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(bookRepositoryProvider);
    final sort = ref.watch(librarySortProvider);
    final filter = ref.watch(libraryFilterProvider);
    final search = ref.watch(librarySearchProvider);
    final isGrid = ref.watch(libraryViewModeProvider);
    final columns = ref.watch(libraryGridColumnsProvider);
    ref.watch(libraryRefreshProvider); // triggers rebuild

    final books = repo.getBooksWithProgress(
      sort: sort,
      filterStatus: filter,
      searchQuery: search.isEmpty ? null : search,
    );
    final continueReading = repo.getMostRecentlyRead();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpineLeaf'),
        actions: [
          // Grid column count indicator (when in grid view)
          if (isGrid)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$columns cols',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          // View mode toggle
          IconButton(
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
            tooltip: isGrid ? 'List View' : 'Grid View',
            onPressed: () {
              ref.read(libraryViewModeProvider.notifier).state = !isGrid;
            },
          ),
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
        ],
      ),
      body: GestureDetector(
        onScaleStart: isGrid ? _onScaleStart : null,
        onScaleUpdate: isGrid ? _onScaleUpdate : null,
        behavior: HitTestBehavior.translucent,
        child: CustomScrollView(
          slivers: [
            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SearchBar(
                  hintText: 'Search books...',
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.search),
                  ),
                  trailing: search.isNotEmpty
                      ? [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              ref.read(librarySearchProvider.notifier).state = '';
                            },
                          ),
                        ]
                      : null,
                  onChanged: (value) {
                    ref.read(librarySearchProvider.notifier).state = value;
                  },
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    context.colorScheme.surfaceContainerHigh,
                  ),
                ),
              ),
            ),

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

            // Book list/grid
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
                    crossAxisCount: columns.clamp(2, 5),
                    childAspectRatio: columns >= 4 ? 0.48 : 0.54,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
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
    final chapters = ref.read(bookRepositoryProvider).getChapters(book.id);
    final currentChapter = progress != null && chapters.isNotEmpty
        ? chapters[progress.currentChapter.clamp(0, chapters.length - 1)]
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/reader', arguments: {
              'bookId': book.id,
              'startChapter': progress?.currentChapter ?? 0,
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Book cover (Category 1 or 2)
                BookCoverWidget(
                  title: book.title,
                  author: book.author,
                  bookId: book.id,
                  coverPath: book.coverPath,
                  width: 72,
                  height: 108,
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue Reading',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        style: context.textTheme.bodySmall,
                      ),
                      if (currentChapter != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ch. ${currentChapter.index + 1}: ${currentChapter.title}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Soda level progress indicator
                      Row(
                        children: [
                          SodaProgressIndicator(
                            progress: bookWithProgress.progressPercent,
                            width: 24,
                            height: 38,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bookWithProgress.progressPercent.asPercent,
                                style: context.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.colorScheme.primary,
                                ),
                              ),
                              Text(
                                'Completed',
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/reader', arguments: {
                      'bookId': book.id,
                      'startChapter': progress?.currentChapter ?? 0,
                    });
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Read'),
                ),
              ],
            ),
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
        Navigator.pushNamed(context, '/book-details', arguments: book.id);
      },
      onLongPress: () => _showContextMenu(context, book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover with progress overlay
          Expanded(
            child: Stack(
              children: [
                BookCoverWidget(
                  title: book.title,
                  author: book.author,
                  bookId: book.id,
                  coverPath: book.coverPath,
                  width: double.infinity,
                ),
                // Soda fill level badge
                if (book.status != BookStatus.unread)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: SodaProgressIndicator(
                      progress: bookWithProgress.progressPercent,
                      width: 22,
                      height: 36,
                      showPercentText: true,
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
          Navigator.pushNamed(context, '/book-details', arguments: book.id);
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
                    Row(
                      children: [
                        SodaProgressIndicator(
                          progress: bookWithProgress.progressPercent,
                          width: 18,
                          height: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bookWithProgress.progressPercent.asPercent,
                          style: context.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${book.totalChapters} chapters',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
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
              Navigator.pushNamed(context, '/reader', arguments: {
                'bookId': book.id,
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Book Details'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/book-details', arguments: book.id);
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
