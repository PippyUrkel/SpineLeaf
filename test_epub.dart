// ignore_for_file: avoid_print
import 'dart:io';
import 'package:epubx/epubx.dart';

void main() async {
  final bytes = await File('apk/demo_epub/Alices Adventures in Wonderland.epub').readAsBytes();
  final epubBook = await EpubReader.readBook(bytes);
  print("Images count: ${epubBook.Content?.Images?.length}");
  if (epubBook.Content?.Images != null) {
    epubBook.Content!.Images!.keys.take(5).forEach((key) => print("Image key: $key"));
  }
}
