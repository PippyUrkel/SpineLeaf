import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../domain/parsers/document_parser.dart';
import '../repositories/repositories.dart';

/// Service responsible for importing books from the file system.
class ImportService {
  final BookRepository _bookRepository;

  ImportService(this._bookRepository);

  Future<void> importBook(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'epub',
          'pdf',
          'rtf',
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
        'pdf' => PdfParser(),
        'rtf' => RtfParserAdapter(),
        'txt' || 'md' => TxtParser(),
        _ => throw UnsupportedError(
            'Unsupported file format: ${extension ?? 'unknown'}',
          ),
      };

      final file = File(path);

      // Copy source file to app's persistent documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final ext = extension ?? 'bin';
      final fileName = 'book_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final persistentFile = await file.copy('${booksDir.path}/$fileName');

      final parsedBook = await parser.parse(persistentFile);

      // Save persistent path on book model
      var finalBook = parsedBook.book.copyWith(
        filePath: persistentFile.path,
      );

      if (finalBook.format == BookFormat.pdf && context.mounted) {
        String title = finalBook.title;
        String author = finalBook.author == 'PDF Document' ? '' : finalBook.author;

        final result = await showDialog<Map<String, String>>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Book Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Title'),
                    controller: TextEditingController(text: title)..selection = TextSelection.collapsed(offset: title.length),
                    onChanged: (val) => title = val,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Author'),
                    controller: TextEditingController(text: author)..selection = TextSelection.collapsed(offset: author.length),
                    onChanged: (val) => author = val,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, {'title': title, 'author': author}),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );

        if (result == null) {
          return; // User cancelled
        }

        if (result['title']?.isNotEmpty == true) {
          finalBook = finalBook.copyWith(title: result['title']);
        }
        if (result['author']?.isNotEmpty == true) {
          finalBook = finalBook.copyWith(author: result['author']);
        }
      }

      _bookRepository.addBook(finalBook);
      _bookRepository.addChapters(
        finalBook.id,
        parsedBook.chapters,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error importing book: $e');
      rethrow;
    }
  }
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.read(bookRepositoryProvider));
});