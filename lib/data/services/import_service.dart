import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/parsers/document_parser.dart';
import '../repositories/repositories.dart';

/// Service responsible for importing books from the file system
class ImportService {
  final BookRepository _bookRepository;

  ImportService(this._bookRepository);

  Future<void> importBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'txt', 'md'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase();

        DocumentParser parser;
        if (extension == 'epub') {
          parser = EpubParser();
        } else if (extension == 'txt' || extension == 'md') {
          parser = TxtParser();
        } else {
          throw Exception('Unsupported file format');
        }

        final parsedBook = await parser.parse(file);
        _bookRepository.addBook(parsedBook.book);
        _bookRepository.addChapters(parsedBook.book.id, parsedBook.chapters);
      }
    } catch (e) {
      // Handle or log error
      // ignore: avoid_print
      print('Error importing book: $e');
      rethrow;
    }
  }
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.read(bookRepositoryProvider));
});
