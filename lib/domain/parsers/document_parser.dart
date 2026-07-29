import 'dart:io';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import 'epub_parser.dart';
import 'rtf_parser.dart';

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

/// EPUB format parser (delegates to StructuredEpubParser for consistency)
class EpubParser implements DocumentParser {
  @override
  Future<ParsedBook> parse(File file) async {
    final structuredParser = StructuredEpubParser();
    final result = await structuredParser.parse(file);
    return ParsedBook(result.book, result.chapters);
  }
}

/// RTF format parser
class RtfParserAdapter implements DocumentParser {
  @override
  Future<ParsedBook> parse(File file) async {
    final rtfParser = RtfParser();
    final result = await rtfParser.parse(file);
    return ParsedBook(result.book, result.chapters);
  }
}

/// PDF format parser
class PdfParser implements DocumentParser {
  @override
  Future<ParsedBook> parse(File file) async {
    final title = file.uri.pathSegments.last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    
    final book = Book(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: 'PDF Document',
      description: file.path, // Store file path in description for backward compatibility
      filePath: file.path,
      publisher: 'Unknown',
      format: BookFormat.pdf,
      totalChapters: 1,
      dateAdded: DateTime.now(),
      status: BookStatus.unread,
      totalWords: 0,
    );

    final chapter = Chapter(
      id: '${book.id}_ch_0',
      bookId: book.id,
      title: title,
      index: 0,
      content: 'PDF Document Content',
      wordCount: 0,
    );

    return ParsedBook(book, [chapter]);
  }
}

/// TXT format parser
class TxtParser implements DocumentParser {
  @override
  Future<ParsedBook> parse(File file) async {
    final content = await file.readAsString();
    final String title = file.uri.pathSegments.last.replaceAll(RegExp(r'\.(txt|md)$', caseSensitive: false), '');
    final wordCount = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final book = Book(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: 'Unknown Author',
      description: 'Imported text document.',
      publisher: 'Unknown',
      format: BookFormat.txt,
      totalChapters: 1,
      dateAdded: DateTime.now(),
      status: BookStatus.unread,
      totalWords: wordCount,
    );

    final chapter = Chapter(
      id: '${book.id}_ch_0',
      bookId: book.id,
      title: 'Full Text',
      index: 0,
      content: content,
      wordCount: wordCount,
    );

    return ParsedBook(book, [chapter]);
  }
}
