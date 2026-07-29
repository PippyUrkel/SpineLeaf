import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Represents the type of a content block within a structured document.
enum ContentBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  image,
  orderedList,
  unorderedList,
  blockquote,
  horizontalRule,
  codeBlock,
}

/// Represents the type of inline formatting within text.
enum InlineStyleType {
  bold,
  italic,
  underline,
  strikethrough,
  code,
  link,
  superscript,
  subscript,
}

/// Represents a span of text with optional inline styling.
class DocInlineSpan {
  final String text;
  final Set<InlineStyleType> styles;
  final String? linkUrl;

  const DocInlineSpan({
    required this.text,
    this.styles = const {},
    this.linkUrl,
  });

  bool get isBold => styles.contains(InlineStyleType.bold);
  bool get isItalic => styles.contains(InlineStyleType.italic);
  bool get isUnderline => styles.contains(InlineStyleType.underline);
  bool get isLink => styles.contains(InlineStyleType.link) && linkUrl != null;

  /// Builds a TextStyle from this span's styles.
  TextStyle toTextStyle(TextStyle base) {
    var style = base;
    if (isBold) style = style.copyWith(fontWeight: FontWeight.bold);
    if (isItalic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (isUnderline) style = style.copyWith(decoration: TextDecoration.underline);
    if (styles.contains(InlineStyleType.strikethrough)) {
      style = style.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (isLink) {
      style = style.copyWith(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      );
    }
    if (styles.contains(InlineStyleType.code)) {
      style = style.copyWith(fontFamily: 'monospace', fontSize: (style.fontSize ?? 14) * 0.9);
    }
    return style;
  }
}

/// Represents a single content block (paragraph, heading, image, etc.)
class ContentBlock {
  final ContentBlockType type;

  /// Inline spans for text-based blocks.
  final List<DocInlineSpan> spans;

  /// The full plain text content of this block (for search, position tracking).
  final String plainText;

  /// Image data for image blocks.
  final Uint8List? imageData;
  final String? imageAlt;
  final String? imageSrc;

  /// List items for list blocks. Each item is a list of DocInlineSpans.
  final List<List<DocInlineSpan>>? listItems;

  /// Text alignment override for this block.
  final TextAlign? textAlign;

  const ContentBlock({
    required this.type,
    this.spans = const [],
    this.plainText = '',
    this.imageData,
    this.imageAlt,
    this.imageSrc,
    this.listItems,
    this.textAlign,
  });

  /// Creates a paragraph block.
  factory ContentBlock.paragraph(List<DocInlineSpan> spans, {TextAlign? textAlign}) {
    return ContentBlock(
      type: ContentBlockType.paragraph,
      spans: spans,
      plainText: spans.map((s) => s.text).join(),
      textAlign: textAlign,
    );
  }

  /// Creates a heading block.
  factory ContentBlock.heading(int level, List<DocInlineSpan> spans) {
    final type = switch (level) {
      1 => ContentBlockType.heading1,
      2 => ContentBlockType.heading2,
      3 => ContentBlockType.heading3,
      4 => ContentBlockType.heading4,
      5 => ContentBlockType.heading5,
      _ => ContentBlockType.heading6,
    };
    return ContentBlock(
      type: type,
      spans: spans,
      plainText: spans.map((s) => s.text).join(),
    );
  }

  /// Creates an image block.
  factory ContentBlock.image({
    Uint8List? imageData,
    String? alt,
    String? src,
  }) {
    return ContentBlock(
      type: ContentBlockType.image,
      imageData: imageData,
      imageAlt: alt,
      imageSrc: src,
    );
  }

  /// Creates an unordered list block.
  factory ContentBlock.unorderedList(List<List<DocInlineSpan>> items) {
    return ContentBlock(
      type: ContentBlockType.unorderedList,
      listItems: items,
      plainText: items.map((item) => item.map((s) => s.text).join()).join('\n'),
    );
  }

  /// Creates an ordered list block.
  factory ContentBlock.orderedList(List<List<DocInlineSpan>> items) {
    return ContentBlock(
      type: ContentBlockType.orderedList,
      listItems: items,
      plainText: items.map((item) => item.map((s) => s.text).join()).join('\n'),
    );
  }

  /// Creates a blockquote.
  factory ContentBlock.blockquote(List<DocInlineSpan> spans) {
    return ContentBlock(
      type: ContentBlockType.blockquote,
      spans: spans,
      plainText: spans.map((s) => s.text).join(),
    );
  }

  /// Creates a horizontal rule.
  factory ContentBlock.horizontalRule() {
    return const ContentBlock(type: ContentBlockType.horizontalRule);
  }

  bool get isHeading => type.index >= ContentBlockType.heading1.index &&
      type.index <= ContentBlockType.heading6.index;

  bool get isImage => type == ContentBlockType.image;
  bool get isList => type == ContentBlockType.orderedList ||
      type == ContentBlockType.unorderedList;

  int get headingLevel {
    if (!isHeading) return 0;
    return type.index - ContentBlockType.heading1.index + 1;
  }

  /// Returns a TextSpan tree for text-based blocks.
  TextSpan toTextSpan(TextStyle baseStyle) {
    if (spans.isEmpty) return TextSpan(text: '', style: baseStyle);
    return TextSpan(
      children: spans.map((span) {
        return TextSpan(
          text: span.text,
          style: span.toTextStyle(baseStyle),
        );
      }).toList(),
    );
  }
}

/// Represents a section/chapter within a structured document.
class DocumentSection {
  final String id;
  final String title;
  final int index;
  final List<ContentBlock> contentBlocks;
  final int wordCount;

  const DocumentSection({
    required this.id,
    required this.title,
    required this.index,
    required this.contentBlocks,
    this.wordCount = 0,
  });

  /// The full plain text of this section.
  String get plainText => contentBlocks.map((b) => b.plainText).join('\n\n');
}

/// Represents a fully parsed structured document.
class StructuredDocument {
  final List<DocumentSection> sections;

  /// Images extracted from the document, keyed by source path/name.
  final Map<String, Uint8List> images;

  const StructuredDocument({
    required this.sections,
    this.images = const {},
  });

  int get totalSections => sections.length;
  int get totalWords => sections.fold<int>(0, (sum, s) => sum + s.wordCount);
}

/// Represents a logical reading position within a document.
/// Survives repagination because it references content, not page numbers.
class ReadingPosition {
  final int chapterIndex;
  final int contentBlockIndex;
  final int characterOffset;

  const ReadingPosition({
    this.chapterIndex = 0,
    this.contentBlockIndex = 0,
    this.characterOffset = 0,
  });

  ReadingPosition copyWith({
    int? chapterIndex,
    int? contentBlockIndex,
    int? characterOffset,
  }) {
    return ReadingPosition(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      contentBlockIndex: contentBlockIndex ?? this.contentBlockIndex,
      characterOffset: characterOffset ?? this.characterOffset,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterIndex': chapterIndex,
    'contentBlockIndex': contentBlockIndex,
    'characterOffset': characterOffset,
  };

  factory ReadingPosition.fromJson(Map<String, dynamic> json) {
    return ReadingPosition(
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      contentBlockIndex: json['contentBlockIndex'] as int? ?? 0,
      characterOffset: json['characterOffset'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'ReadingPosition(ch:$chapterIndex, block:$contentBlockIndex, offset:$characterOffset)';
}

/// Document type classification for reader behavior.
enum DocumentType {
  /// Reflowable text documents (EPUB, RTF, TXT)
  reflowable,
  /// Fixed-layout documents (PDF)
  fixedLayout,
}
