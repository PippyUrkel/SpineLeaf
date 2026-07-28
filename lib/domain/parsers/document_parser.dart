import 'dart:io';
import 'package:epubx/epubx.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
/// Represents a parsed book result
class ParsedBook {
  final Book book;
  final List<Chapter> chapters;

  ParsedBook(this.book, this.chapters);
}

/// Abstract document parser
abstract class DocumentParser {
  Future<ParsedBook> parse(File file);
}

/// EPUB format parser
class EpubParser implements DocumentParser {
  @override
  Future<ParsedBook> parse(File file) async {
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final String title = epubBook.Title ?? 'Unknown Title';
    final String author = epubBook.Author ?? 'Unknown Author';
    
    final book = Book(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: author,
      description: 'Imported EPUB book.',
      publisher: 'Unknown',
      format: BookFormat.epub,
      totalChapters: epubBook.Chapters?.length ?? 0,
      dateAdded: DateTime.now(),
      status: BookStatus.unread,
      totalWords: 0,
    );

    final List<Chapter> chapters = [];
    int totalWords = 0;

    if (epubBook.Chapters != null) {
      for (int i = 0; i < epubBook.Chapters!.length; i++) {
        final chapter = epubBook.Chapters![i];
        final content = _stripHtml(chapter.HtmlContent ?? '');
        final wordCount = content.split(RegExp(r'\s+')).length;
        totalWords += wordCount;

        chapters.add(Chapter(
          id: '${book.id}_ch_$i',
          bookId: book.id,
          title: chapter.Title ?? 'Chapter ${i + 1}',
          index: i,
          content: content,
          wordCount: wordCount,
        ));
      }
    }

    return ParsedBook(
      book.copyWith(totalWords: totalWords, totalChapters: chapters.length),
      chapters,
    );
  }

  String _stripHtml(String htmlString) {
    // Basic HTML stripping for demo purposes
    final regExp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(regExp, '').replaceAll('&nbsp;', ' ').trim();
  }
}

/// TXT format parser
class TxtParser implements DocumentParser {
  @override
  Future<ParsedBook> parse(File file) async {
    final content = await file.readAsString();
    final String title = file.uri.pathSegments.last.replaceAll('.txt', '');
    
    final book = Book(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: 'Unknown Author',
      description: 'Imported TXT document.',
      publisher: 'Unknown',
      format: BookFormat.txt,
      totalChapters: 1,
      dateAdded: DateTime.now(),
      status: BookStatus.unread,
      totalWords: content.split(RegExp(r'\s+')).length,
    );

    final chapter = Chapter(
      id: '${book.id}_ch_0',
      bookId: book.id,
      title: 'Full Text',
      index: 0,
      content: content,
      wordCount: book.totalWords,
    );

    return ParsedBook(book, [chapter]);
  }
}
