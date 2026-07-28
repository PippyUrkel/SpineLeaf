import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../widgets/book_cover.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedBookId;
  List<SearchResult> _bookResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _query = query;
      if (_selectedBookId != null && query.isNotEmpty) {
        _bookResults = ref.read(bookRepositoryProvider).searchInBook(_selectedBookId!, query);
      } else {
        _bookResults = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(bookRepositoryProvider);
    final allBooks = repo.allBooks;

    // Library search results
    final libraryResults = _query.isEmpty
        ? <Book>[]
        : allBooks.where((b) {
            final q = _query.toLowerCase();
            return b.title.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: _selectedBookId != null
                  ? 'Search inside book...'
                  : 'Search library by title or author...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  ),
              ],
              onChanged: _search,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                context.colorScheme.surfaceContainerHigh,
              ),
            ),
          ),

          // Book selector for in-book search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_selectedBookId != null) ...[
                  InputChip(
                    label: Text(repo.getBook(_selectedBookId!)?.title ?? 'Book'),
                    avatar: const Icon(Icons.menu_book, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedBookId = null;
                        _bookResults = [];
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() {
                        _selectedBookId = null;
                        _bookResults = [];
                      });
                    },
                  ),
                ] else ...[
                  Text('Search in: ', style: context.textTheme.bodySmall),
                  const SizedBox(width: 4),
                  ActionChip(
                    label: const Text('Library'),
                    avatar: const Icon(Icons.library_books, size: 16),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    child: ActionChip(
                      label: const Text('Specific Book'),
                      avatar: const Icon(Icons.book, size: 16),
                      onPressed: null,
                    ),
                    itemBuilder: (_) => allBooks.map((b) {
                      return PopupMenuItem(
                        value: b.id,
                        child: Text(b.title),
                      );
                    }).toList(),
                    onSelected: (bookId) {
                      setState(() {
                        _selectedBookId = bookId;
                        if (_query.isNotEmpty) _search(_query);
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _query.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 64, color: context.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'Search your library',
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search by title, author, or inside a book',
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : _selectedBookId != null
                    ? _InBookResults(results: _bookResults)
                    : _LibraryResults(results: libraryResults),
          ),
        ],
      ),
    );
  }
}

class _LibraryResults extends StatelessWidget {
  final List<Book> results;

  const _LibraryResults({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text('No books found', style: context.textTheme.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final book = results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: BookCoverWidget(
              title: book.title,
              author: book.author,
              bookId: book.id,
              width: 40,
              height: 60,
            ),
            title: Text(book.title),
            subtitle: Text(book.author),
            trailing: Text(book.status.label, style: context.textTheme.labelSmall),
            onTap: () {
              Navigator.pushNamed(context, '/book-details', arguments: book.id);
            },
          ),
        );
      },
    );
  }
}

class _InBookResults extends StatelessWidget {
  final List<SearchResult> results;

  const _InBookResults({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Text('No matches found', style: context.textTheme.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 16,
              child: Text('${result.chapterIndex + 1}'),
            ),
            title: Text(
              result.excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall,
            ),
            subtitle: Text(
              result.chapterTitle,
              style: context.textTheme.labelSmall,
            ),
            onTap: () {
              Navigator.pushNamed(context, '/reader', arguments: {
                'bookId': result.bookId,
                'startChapter': result.chapterIndex,
              });
            },
          ),
        );
      },
    );
  }
}
