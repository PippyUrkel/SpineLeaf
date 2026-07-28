import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/parsers/document_parser.dart';
import '../repositories/repositories.dart';

/// Service responsible for importing books from the file system.
class ImportService {
  final BookRepository _bookRepository;

  ImportService(this._bookRepository);

  Future<void> importBook() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'epub',
          'txt',
          'md',
        ],
        allowMultiple: false,
      );

      // User cancelled the picker.
      if (result == null) {
        return;
      }

      final pickedFile = result.files.single;
      final path = pickedFile.path;

      if (path == null) {
        throw Exception('Unable to access the selected file.');
      }

      final extension = pickedFile.extension?.toLowerCase();

      final DocumentParser parser = switch (extension) {
        'epub' => EpubParser(),
        'txt' || 'md' => TxtParser(),
        _ => throw UnsupportedError(
            'Unsupported file format: ${extension ?? 'unknown'}',
          ),
      };

      final file = File(path);
      final parsedBook = await parser.parse(file);

      _bookRepository.addBook(parsedBook.book);
      _bookRepository.addChapters(
        parsedBook.book.id,
        parsedBook.chapters,
      );
    } catch (e) {
      // TODO: Replace with application logging/error handling.
      // ignore: avoid_print
      print('Error importing book: $e');
      rethrow;
    }
  }
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.read(bookRepositoryProvider));
});