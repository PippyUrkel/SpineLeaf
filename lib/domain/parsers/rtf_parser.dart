import 'dart:io';
import 'package:flutter/material.dart';
import '../models/structured_document.dart';
import '../../core/constants.dart';
import '../../data/models/models.dart';
import 'epub_parser.dart';

/// Parses RTF (Rich Text Format) files into structured documents.
/// Handles common RTF control codes for formatting.
class RtfParser {
  Future<ParsedStructuredBook> parse(File file) async {
    final content = await file.readAsString();
    final String title = file.uri.pathSegments.last.replaceAll('.rtf', '');

    // Parse RTF into content blocks
    final contentBlocks = _parseRtf(content);

    final plainText = contentBlocks.map((b) => b.plainText).join(' ');
    final wordCount = plainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final section = DocumentSection(
      id: 'section_0',
      title: title,
      index: 0,
      contentBlocks: contentBlocks,
      wordCount: wordCount,
    );

    final book = Book(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: 'Unknown Author',
      description: 'Imported RTF document.',
      filePath: file.path,
      publisher: 'Unknown',
      format: BookFormat.rtf,
      totalChapters: 1,
      dateAdded: DateTime.now(),
      status: BookStatus.unread,
      totalWords: wordCount,
    );

    final chapter = Chapter(
      id: '${book.id}_ch_0',
      bookId: book.id,
      title: title,
      index: 0,
      content: plainText,
      wordCount: wordCount,
    );

    return ParsedStructuredBook(
      book,
      [chapter],
      StructuredDocument(sections: [section]),
    );
  }

  /// Parses RTF content into ContentBlocks.
  List<ContentBlock> _parseRtf(String rtf) {
    final blocks = <ContentBlock>[];

    // Skip RTF header (font table, color table, etc.)
    final bodyStart = _findBodyStart(rtf);
    if (bodyStart < 0) {
      // Not valid RTF, treat as plain text
      return [ContentBlock.paragraph([DocInlineSpan(text: rtf)])];
    }

    final body = rtf.substring(bodyStart);

    // State tracking
    var currentBold = false;
    var currentItalic = false;
    var currentUnderline = false;
    var currentAlign = TextAlign.left;
    final buffer = StringBuffer();
    final spans = <DocInlineSpan>[];
    var inGroup = 0;

    int i = 0;
    while (i < body.length) {
      final char = body[i];

      if (char == '{') {
        inGroup++;
        i++;
        continue;
      }

      if (char == '}') {
        inGroup--;
        if (inGroup < 0) break; // End of document
        i++;
        continue;
      }

      if (char == '\\') {
        // Control word
        i++;
        if (i >= body.length) break;

        final nextChar = body[i];

        // Escaped special characters
        if (nextChar == '\\' || nextChar == '{' || nextChar == '}') {
          buffer.write(nextChar);
          i++;
          continue;
        }

        // Line break
        if (nextChar == '\n' || nextChar == '\r') {
          i++;
          continue;
        }

        // Read control word
        final wordStart = i;
        while (i < body.length && body[i].isAlpha) {
          i++;
        }
        final controlWord = body.substring(wordStart, i);

        // Read optional numeric parameter
        final numStart = i;
        if (i < body.length && (body[i] == '-' || body[i].isDigit)) {
          i++;
          while (i < body.length && body[i].isDigit) {
            i++;
          }
        }
        final numStr = body.substring(numStart, i);
        final num = numStr.isEmpty ? null : int.tryParse(numStr);

        // Skip optional space after control word
        if (i < body.length && body[i] == ' ') {
          i++;
        }

        switch (controlWord) {
          case 'par':
          case 'line':
            // End of paragraph
            _flushSpans(buffer, spans, currentBold, currentItalic, currentUnderline);
            if (spans.isNotEmpty) {
              blocks.add(ContentBlock.paragraph(List.of(spans), textAlign: currentAlign));
              spans.clear();
            }
            break;

          case 'pard':
            // Reset paragraph formatting
            _flushSpans(buffer, spans, currentBold, currentItalic, currentUnderline);
            if (spans.isNotEmpty) {
              blocks.add(ContentBlock.paragraph(List.of(spans), textAlign: currentAlign));
              spans.clear();
            }
            currentBold = false;
            currentItalic = false;
            currentUnderline = false;
            currentAlign = TextAlign.left;
            break;

          case 'b':
            _flushSpans(buffer, spans, currentBold, currentItalic, currentUnderline);
            currentBold = num != 0; // \b0 turns off bold
            break;

          case 'i':
            _flushSpans(buffer, spans, currentBold, currentItalic, currentUnderline);
            currentItalic = num != 0;
            break;

          case 'ul':
          case 'ulnone':
            _flushSpans(buffer, spans, currentBold, currentItalic, currentUnderline);
            currentUnderline = controlWord == 'ul' && num != 0;
            break;

          case 'ql':
            currentAlign = TextAlign.left;
            break;
          case 'qr':
            currentAlign = TextAlign.right;
            break;
          case 'qc':
            currentAlign = TextAlign.center;
            break;
          case 'qj':
            currentAlign = TextAlign.justify;
            break;

          case 'fs':
            break;

          case 'tab':
            buffer.write('\t');
            break;

          case 'emdash':
            buffer.write('—');
            break;
          case 'endash':
            buffer.write('–');
            break;
          case 'lquote':
            buffer.write('\u2018');
            break;
          case 'rquote':
            buffer.write('\u2019');
            break;
          case 'ldblquote':
            buffer.write('\u201C');
            break;
          case 'rdblquote':
            buffer.write('\u201D');
            break;
          case 'bullet':
            buffer.write('\u2022');
            break;

          case 'u':
            // Unicode character
            if (num != null) {
              buffer.write(String.fromCharCode(num < 0 ? num + 65536 : num));
              // Skip replacement character
              if (i < body.length && body[i] == '?') i++;
            }
            break;

          // Skip known control words that we don't render
          case 'fonttbl':
          case 'colortbl':
          case 'stylesheet':
          case 'info':
          case 'pict':
            // Skip the entire group
            var depth = 1;
            while (i < body.length && depth > 0) {
              if (body[i] == '{') depth++;
              if (body[i] == '}') depth--;
              i++;
            }
            break;

          default:
            // Unknown control word, skip
            break;
        }
        continue;
      }

      // Regular text
      if (char != '\n' && char != '\r') {
        buffer.write(char);
      }
      i++;
    }

    // Flush remaining content
    _flushSpans(buffer, spans, currentBold, currentItalic, currentUnderline);
    if (spans.isNotEmpty) {
      blocks.add(ContentBlock.paragraph(List.of(spans), textAlign: currentAlign));
    }

    // Post-process: detect headings (large/bold paragraphs at start)
    _detectHeadings(blocks);

    return blocks;
  }

  /// Flushes the current text buffer into a span.
  void _flushSpans(
    StringBuffer buffer,
    List<DocInlineSpan> spans,
    bool bold,
    bool italic,
    bool underline,
  ) {
    if (buffer.isEmpty) return;

    final text = buffer.toString();
    buffer.clear();

    final styles = <InlineStyleType>{};
    if (bold) styles.add(InlineStyleType.bold);
    if (italic) styles.add(InlineStyleType.italic);
    if (underline) styles.add(InlineStyleType.underline);

    spans.add(DocInlineSpan(text: text, styles: styles));
  }

  /// Detects headings by heuristic: short bold paragraphs at the beginning
  /// or short bold-only paragraphs throughout the document.
  void _detectHeadings(List<ContentBlock> blocks) {
    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.type != ContentBlockType.paragraph) continue;
      if (block.spans.isEmpty) continue;

      // Check if all spans are bold and the text is short (likely a heading)
      final allBold = block.spans.every((s) => s.isBold);
      final totalLen = block.plainText.length;
      if (allBold && totalLen > 0 && totalLen < 120) {
        blocks[i] = ContentBlock.heading(
          i < 2 ? 1 : 2,
          block.spans,
        );
      }
    }
  }

  /// Finds where the actual body content starts (after the RTF header).
  int _findBodyStart(String rtf) {
    if (!rtf.startsWith('{\\rtf')) return -1;

    // Skip past font table, color table, stylesheet, etc.
    int i = 5;

    // Skip the main header properties
    while (i < rtf.length) {
      if (rtf[i] == '{') {
        // Check if this is a header group we should skip
        final ahead = rtf.substring(i, (i + 20).clamp(0, rtf.length));
        if (ahead.startsWith('{\\fonttbl') ||
            ahead.startsWith('{\\colortbl') ||
            ahead.startsWith('{\\stylesheet') ||
            ahead.startsWith('{\\info') ||
            ahead.startsWith('{\\*')) {
          // Skip this group
          int depth = 1;
          i++;
          while (i < rtf.length && depth > 0) {
            if (rtf[i] == '{') depth++;
            if (rtf[i] == '}') depth--;
            i++;
          }
          continue;
        }
        break;
      }

      if (rtf[i] == '\\') {
        // Skip control word
        i++;
        while (i < rtf.length && rtf[i].isAlpha) {
          i++;
        }
        // Skip optional number
        if (i < rtf.length && (rtf[i] == '-' || rtf[i].isDigit)) {
          i++;
          while (i < rtf.length && rtf[i].isDigit) {
            i++;
          }
        }
        // Skip optional space
        if (i < rtf.length && rtf[i] == ' ') {
          i++;
        }
        continue;
      }

      i++;
    }

    return i;
  }
}

extension _CharExt on String {
  bool get isAlpha {
    if (isEmpty) return false;
    final code = codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool get isDigit {
    if (isEmpty) return false;
    final code = codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
