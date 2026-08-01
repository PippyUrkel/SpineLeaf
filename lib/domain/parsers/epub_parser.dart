import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/structured_document.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';

/// Result of parsing an EPUB file into a structured document.
class ParsedStructuredBook {
  final Book book;
  final List<Chapter> chapters; // Backward-compatible plain-text chapters
  final StructuredDocument document; // New structured representation

  ParsedStructuredBook(this.book, this.chapters, this.document);
}

/// Parses EPUB files into structured documents preserving formatting and images.
class StructuredEpubParser {
  /// Parses an EPUB file and returns both legacy chapters and structured document.
  Future<ParsedStructuredBook> parse(File file) async {
    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final String title = epubBook.Title ?? 'Unknown Title';
    final String author = epubBook.Author ?? 'Unknown Author';

    // Extract images from the EPUB
    final Map<String, Uint8List> images = _extractImages(epubBook);

    // Parse chapters into structured sections
    final List<DocumentSection> sections = [];
    final List<Chapter> legacyChapters = [];
    int totalWords = 0;

    if (epubBook.Chapters != null) {
      for (int i = 0; i < epubBook.Chapters!.length; i++) {
        final chapter = epubBook.Chapters![i];
        final htmlContent = chapter.HtmlContent ?? '';
        final chapterTitle = chapter.Title ?? 'Chapter ${i + 1}';

        // Parse HTML into content blocks
        final contentBlocks = _parseHtmlToBlocks(htmlContent, images);

        // Calculate word count from blocks
        final plainText = contentBlocks.map((b) => b.plainText).join(' ');
        final wordCount = plainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        totalWords += wordCount;

        sections.add(DocumentSection(
          id: 'section_$i',
          title: chapterTitle,
          index: i,
          contentBlocks: contentBlocks,
          wordCount: wordCount,
        ));

        // Legacy chapter for backward compatibility (search, etc.)
        legacyChapters.add(Chapter(
          id: 'ch_$i',
          bookId: '',  // Will be set by caller
          title: chapterTitle,
          index: i,
          content: plainText,
          wordCount: wordCount,
        ));
      }
    }

    String? coverPath;
    try {
      Uint8List? coverBytes;
      if (epubBook.CoverImage != null) {
        coverBytes = Uint8List.fromList(img.encodePng(epubBook.CoverImage!));
      } else if (images.isNotEmpty) {
        final coverKey = images.keys.firstWhere(
          (k) => k.toLowerCase().contains('cover'),
          orElse: () => images.keys.first,
        );
        coverBytes = images[coverKey];
      }

      if (coverBytes != null && coverBytes.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final coversDir = Directory('${appDir.path}/covers');
        if (!coversDir.existsSync()) {
          coversDir.createSync(recursive: true);
        }
        final coverFile = File('${coversDir.path}/cover_${DateTime.now().millisecondsSinceEpoch}.png');
        await coverFile.writeAsBytes(coverBytes);
        coverPath = coverFile.path;
      }
    } catch (_) {}

    final book = Book(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: author,
      coverPath: coverPath,
      description: 'Imported EPUB book.',
      filePath: file.path,
      publisher: 'Unknown',
      format: BookFormat.epub,
      totalChapters: sections.length,
      dateAdded: DateTime.now(),
      status: BookStatus.unread,
      totalWords: totalWords,
    );

    // Update chapter bookIds
    final chapters = legacyChapters.map((c) => Chapter(
      id: '${book.id}_${c.id}',
      bookId: book.id,
      title: c.title,
      index: c.index,
      content: c.content,
      wordCount: c.wordCount,
    )).toList();

    return ParsedStructuredBook(
      book,
      chapters,
      StructuredDocument(sections: sections, images: images),
    );
  }

  /// Extracts all images from the EPUB book.
  Map<String, Uint8List> _extractImages(EpubBook epubBook) {
    final images = <String, Uint8List>{};

    if (epubBook.Content?.Images != null) {
      for (final entry in epubBook.Content!.Images!.entries) {
        final imageContent = entry.value;
        if (imageContent.Content != null) {
          final bytes = Uint8List.fromList(imageContent.Content!);
          final rawKey = entry.key;
          final decodedKey = Uri.decodeFull(rawKey);
          final filename = rawKey.split('/').last;
          final decodedFilename = decodedKey.split('/').last;

          images[rawKey] = bytes;
          images[decodedKey] = bytes;
          images[filename] = bytes;
          images[decodedFilename] = bytes;
          images[filename.toLowerCase()] = bytes;
          images[decodedFilename.toLowerCase()] = bytes;
          images[rawKey.replaceAll('../', '')] = bytes;
          images[decodedKey.replaceAll('../', '')] = bytes;
        }
      }
    }

    return images;
  }

  /// Parses HTML content into a list of ContentBlocks.
  List<ContentBlock> _parseHtmlToBlocks(
    String html,
    Map<String, Uint8List> images,
  ) {
    final blocks = <ContentBlock>[];

    // Remove doctype, head, and body wrappers
    var content = html
        .replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<html[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</html>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<head>.*?</head>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<body[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</body>', caseSensitive: false), '')
        .trim();

    // Split into block-level elements
    final blockPattern = RegExp(
      r'<(p|h[1-6]|div|blockquote|ul|ol|hr|img|pre|figure|figcaption|svg|image)(\s[^>]*)?>(.*?)</\1>|<(hr|img|br|image)(\s[^>]*)?\s*/?>',
      caseSensitive: false,
      dotAll: true,
    );

    int lastEnd = 0;
    for (final match in blockPattern.allMatches(content)) {
      // Check for text between tags
      if (match.start > lastEnd) {
        final between = content.substring(lastEnd, match.start).trim();
        if (between.isNotEmpty) {
          final spans = _parseInlineContent(between);
          if (spans.isNotEmpty && spans.any((s) => s.text.trim().isNotEmpty)) {
            blocks.add(ContentBlock.paragraph(spans));
          }
        }
      }

      final tag = (match.group(1) ?? match.group(4) ?? '').toLowerCase();
      final attrs = match.group(2) ?? match.group(5) ?? '';
      final innerHtml = match.group(3) ?? '';

      switch (tag) {
        case 'p':
        case 'div':
          final spans = _parseInlineContent(innerHtml);
          if (spans.isNotEmpty && spans.any((s) => s.text.trim().isNotEmpty)) {
            // Check for alignment in attributes
            TextAlign? align;
            final alignMatch = RegExp(r'text-align:\s*(left|center|right|justify)', caseSensitive: false)
                .firstMatch(attrs + innerHtml);
            if (alignMatch != null) {
              align = switch (alignMatch.group(1)?.toLowerCase()) {
                'center' => TextAlign.center,
                'right' => TextAlign.right,
                'justify' => TextAlign.justify,
                _ => null,
              };
            }
            blocks.add(ContentBlock.paragraph(spans, textAlign: align));
          }
          // Also check for embedded images
          _extractImagesFromHtml(innerHtml, images, blocks);
          break;

        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          final level = int.parse(tag.substring(1));
          final spans = _parseInlineContent(innerHtml);
          if (spans.isNotEmpty) {
            blocks.add(ContentBlock.heading(level, spans));
          }
          break;

        case 'blockquote':
          final spans = _parseInlineContent(innerHtml);
          if (spans.isNotEmpty) {
            blocks.add(ContentBlock.blockquote(spans));
          }
          break;

        case 'ul':
          final items = _parseListItems(innerHtml);
          if (items.isNotEmpty) {
            blocks.add(ContentBlock.unorderedList(items));
          }
          break;

        case 'ol':
          final items = _parseListItems(innerHtml);
          if (items.isNotEmpty) {
            blocks.add(ContentBlock.orderedList(items));
          }
          break;

        case 'hr':
          blocks.add(ContentBlock.horizontalRule());
          break;

        case 'img':
        case 'image':
          _addImageBlock(attrs, images, blocks);
          break;

        case 'svg':
          _extractImagesFromHtml(innerHtml, images, blocks);
          break;

        case 'pre':
          final text = _stripAllTags(innerHtml);
          if (text.trim().isNotEmpty) {
            blocks.add(ContentBlock(
              type: ContentBlockType.codeBlock,
              spans: [DocInlineSpan(text: text)],
              plainText: text,
            ));
          }
          break;

        case 'figure':
          // Extract img from figure
          _extractImagesFromHtml(innerHtml, images, blocks);
          // Extract figcaption text
          final captionMatch = RegExp(r'<figcaption[^>]*>(.*?)</figcaption>', caseSensitive: false, dotAll: true)
              .firstMatch(innerHtml);
          if (captionMatch != null) {
            final captionSpans = _parseInlineContent(captionMatch.group(1) ?? '');
            if (captionSpans.isNotEmpty) {
              blocks.add(ContentBlock.paragraph(captionSpans, textAlign: TextAlign.center));
            }
          }
          break;
      }

      lastEnd = match.end;
    }

    // Handle remaining text after last tag
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        final spans = _parseInlineContent(remaining);
        if (spans.isNotEmpty && spans.any((s) => s.text.trim().isNotEmpty)) {
          blocks.add(ContentBlock.paragraph(spans));
        }
      }
    }

    // If no blocks were found, try to use the entire content as a paragraph
    if (blocks.isEmpty && content.trim().isNotEmpty) {
      final plainText = _stripAllTags(content);
      if (plainText.trim().isNotEmpty) {
        blocks.add(ContentBlock.paragraph([DocInlineSpan(text: plainText)]));
      }
    }

    return blocks;
  }

  /// Extracts image tags from HTML and adds image blocks.
  void _extractImagesFromHtml(
    String html,
    Map<String, Uint8List> images,
    List<ContentBlock> blocks,
  ) {
    final imgPattern = RegExp(r'<(?:img|image)\s+([^>]*)/?>', caseSensitive: false);
    for (final match in imgPattern.allMatches(html)) {
      _addImageBlock(match.group(1) ?? '', images, blocks);
    }
  }

  /// Creates and adds an image ContentBlock from img tag attributes.
  void _addImageBlock(
    String attrs,
    Map<String, Uint8List> images,
    List<ContentBlock> blocks,
  ) {
    // Match src="..." or src='...' or href="..." or xlink:href="..."
    final srcMatch = RegExp(r'''(?:src|href|xlink:href)=["']([^"']*)["']''', caseSensitive: false).firstMatch(attrs);
    final altMatch = RegExp(r'''alt=["']([^"']*)["']''', caseSensitive: false).firstMatch(attrs);

    if (srcMatch != null) {
      final src = srcMatch.group(1) ?? '';
      final alt = altMatch?.group(1);

      // Try to find the image data
      Uint8List? imageData;
      imageData = images[src];
      if (imageData == null) {
        // Try with just filename
        final filename = src.split('/').last;
        imageData = images[filename];
      }
      if (imageData == null) {
        // Try partial path matching
        for (final key in images.keys) {
          if (key.endsWith(src) || src.endsWith(key.split('/').last)) {
            imageData = images[key];
            break;
          }
        }
      }

      blocks.add(ContentBlock.image(
        imageData: imageData,
        alt: alt,
        src: src,
      ));
    }
  }

  /// Parses inline HTML content into DocInlineSpans, preserving formatting.
  List<DocInlineSpan> _parseInlineContent(String html) {
    final spans = <DocInlineSpan>[];
    if (html.trim().isEmpty) return spans;

    // Normalize whitespace
    html = html.replaceAll(RegExp(r'\s+'), ' ');

    // Replace <br> with newline markers
    html = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Parse inline tags recursively
    _parseInlineRecursive(html, <InlineStyleType>{}, spans);

    return spans;
  }

  void _parseInlineRecursive(
    String html,
    Set<InlineStyleType> currentStyles,
    List<DocInlineSpan> spans,
  ) {
    // Pattern for inline formatting tags
    final inlinePattern = RegExp(
      r'<(b|strong|i|em|u|s|del|strike|span|a|sub|sup|code)(\s[^>]*)?>(.*?)</\1>',
      caseSensitive: false,
      dotAll: true,
    );

    int lastEnd = 0;
    for (final match in inlinePattern.allMatches(html)) {
      // Text before this tag
      if (match.start > lastEnd) {
        final text = _decodeEntities(html.substring(lastEnd, match.start));
        // Strip any remaining tags
        final cleanText = _stripAllTags(text);
        if (cleanText.isNotEmpty) {
          spans.add(DocInlineSpan(text: cleanText, styles: Set.of(currentStyles)));
        }
      }

      final tag = match.group(1)!.toLowerCase();
      final attrs = match.group(2) ?? '';
      final innerHtml = match.group(3) ?? '';

      // Determine new styles for this tag
      final newStyles = Set<InlineStyleType>.of(currentStyles);
      String? linkUrl;

      switch (tag) {
        case 'b':
        case 'strong':
          newStyles.add(InlineStyleType.bold);
          break;
        case 'i':
        case 'em':
          newStyles.add(InlineStyleType.italic);
          break;
        case 'u':
          newStyles.add(InlineStyleType.underline);
          break;
        case 's':
        case 'del':
        case 'strike':
          newStyles.add(InlineStyleType.strikethrough);
          break;
        case 'code':
          newStyles.add(InlineStyleType.code);
          break;
        case 'sub':
          newStyles.add(InlineStyleType.subscript);
          break;
        case 'sup':
          newStyles.add(InlineStyleType.superscript);
          break;
        case 'a':
          newStyles.add(InlineStyleType.link);
          final hrefMatch = RegExp(r'href="([^"]*)"').firstMatch(attrs);
          linkUrl = hrefMatch?.group(1);
          break;
        case 'span':
          // Check for bold/italic in style attribute
          if (attrs.contains('font-weight') && (attrs.contains('bold') || attrs.contains('700'))) {
            newStyles.add(InlineStyleType.bold);
          }
          if (attrs.contains('font-style') && attrs.contains('italic')) {
            newStyles.add(InlineStyleType.italic);
          }
          if (attrs.contains('text-decoration') && attrs.contains('underline')) {
            newStyles.add(InlineStyleType.underline);
          }
          break;
      }

      // Check if inner content has more tags
      if (inlinePattern.hasMatch(innerHtml)) {
        _parseInlineRecursive(innerHtml, newStyles, spans);
      } else {
        final text = _decodeEntities(_stripAllTags(innerHtml));
        if (text.isNotEmpty) {
          spans.add(DocInlineSpan(
            text: text,
            styles: newStyles,
            linkUrl: linkUrl,
          ));
        }
      }

      lastEnd = match.end;
    }

    // Remaining text after last tag
    if (lastEnd < html.length) {
      final text = _decodeEntities(html.substring(lastEnd));
      final cleanText = _stripAllTags(text);
      if (cleanText.isNotEmpty) {
        spans.add(DocInlineSpan(text: cleanText, styles: Set.of(currentStyles)));
      }
    }
  }

  /// Parses <li> elements from a list's inner HTML.
  List<List<DocInlineSpan>> _parseListItems(String html) {
    final items = <List<DocInlineSpan>>[];
    final liPattern = RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true);
    for (final match in liPattern.allMatches(html)) {
      final spans = _parseInlineContent(match.group(1) ?? '');
      if (spans.isNotEmpty) {
        items.add(spans);
      }
    }
    return items;
  }

  /// Strips all HTML tags from a string.
  String _stripAllTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .trim();
  }

  /// Decodes common HTML entities.
  String _decodeEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&lsquo;', ''')
        .replaceAll('&rsquo;', ''')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"');
  }
}
