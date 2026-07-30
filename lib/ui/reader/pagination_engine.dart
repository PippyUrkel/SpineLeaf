import 'package:flutter/material.dart';
import '../../domain/models/structured_document.dart';
import '../../data/models/models.dart';

/// A page computed by the pagination engine.
class ReaderPage {
  /// The content blocks on this page.
  final List<ContentBlock> blocks;

  /// Index of the first block on this page within the chapter.
  final int startBlockIndex;

  /// Character offset into the first block where this page starts (for partial blocks).
  final int startCharOffset;

  /// Index of the last block on this page within the chapter.
  final int endBlockIndex;

  const ReaderPage({
    required this.blocks,
    required this.startBlockIndex,
    this.startCharOffset = 0,
    required this.endBlockIndex,
  });
}

/// The result of paginating a chapter/section.
class PaginatedChapter {
  final int sectionIndex;
  final List<ReaderPage> pages;

  const PaginatedChapter({
    required this.sectionIndex,
    required this.pages,
  });

  int get pageCount => pages.length;
}

/// Computes layout-based pagination for reflowable content.
///
/// Uses TextPainter to measure actual rendered sizes of content blocks,
/// then groups blocks into pages that fit within the viewport.
class PaginationEngine {
  /// Paginates a document section into pages that fit the given constraints.
  PaginatedChapter paginate({
    required DocumentSection section,
    required Size viewportSize,
    required ReaderSettings settings,
    Map<String, dynamic>? imageCache,
  }) {
    final availableWidth = viewportSize.width;
    final availableHeight = viewportSize.height;

    if (availableWidth <= 0 || availableHeight <= 0) {
      return PaginatedChapter(sectionIndex: section.index, pages: []);
    }

    final originalBlocks = section.contentBlocks;
    if (originalBlocks.isEmpty) {
      return PaginatedChapter(
        sectionIndex: section.index,
        pages: [
          ReaderPage(blocks: [], startBlockIndex: 0, endBlockIndex: 0),
        ],
      );
    }

    final blockQueue = List<ContentBlock>.of(originalBlocks);
    final pages = <ReaderPage>[];
    var currentPageBlocks = <ContentBlock>[];
    var currentHeight = 0.0;
    var pageStartBlockIndex = 0;
    int currentOriginalIndex = 0;

    while (blockQueue.isNotEmpty) {
      final block = blockQueue.removeAt(0);
      final blockHeight = _measureBlock(block, availableWidth, settings);
      final spacingAfter = _blockSpacing(block, settings);

      // Check if adding block overflows current page
      if (currentHeight + blockHeight + spacingAfter > availableHeight) {
        if (currentPageBlocks.isNotEmpty) {
          // Finish current page and re-process this block on a fresh page
          pages.add(ReaderPage(
            blocks: List.of(currentPageBlocks),
            startBlockIndex: pageStartBlockIndex,
            endBlockIndex: currentOriginalIndex,
          ));
          currentPageBlocks = [];
          currentHeight = 0.0;
          pageStartBlockIndex = currentOriginalIndex;
          blockQueue.insert(0, block);
          continue;
        }

        // On a fresh page, if block is taller than availableHeight: SLICE IT!
        if (block.spans.isNotEmpty && _isSliceableType(block.type)) {
          final targetHeight = (availableHeight - 20).clamp(50.0, availableHeight);
          final split = _sliceBlock(block, availableWidth, targetHeight, settings);
          if (split != null && split.first.spans.isNotEmpty && split.second.spans.isNotEmpty) {
            currentPageBlocks.add(split.first);
            pages.add(ReaderPage(
              blocks: List.of(currentPageBlocks),
              startBlockIndex: pageStartBlockIndex,
              endBlockIndex: currentOriginalIndex,
            ));
            currentPageBlocks = [];
            currentHeight = 0.0;
            pageStartBlockIndex = currentOriginalIndex;

            // Push remainder back to queue for subsequent pages
            blockQueue.insert(0, split.second);
            continue;
          }
        }
      }

      // Block fits on current page!
      currentPageBlocks.add(block);
      currentHeight += blockHeight + spacingAfter;
      currentOriginalIndex++;
    }

    if (currentPageBlocks.isNotEmpty) {
      pages.add(ReaderPage(
        blocks: List.of(currentPageBlocks),
        startBlockIndex: pageStartBlockIndex,
        endBlockIndex: originalBlocks.length - 1,
      ));
    }

    if (pages.isEmpty) {
      pages.add(ReaderPage(
        blocks: [],
        startBlockIndex: 0,
        endBlockIndex: 0,
      ));
    }

    return PaginatedChapter(sectionIndex: section.index, pages: pages);
  }

  bool _isSliceableType(ContentBlockType type) {
    return type == ContentBlockType.paragraph ||
        type == ContentBlockType.blockquote ||
        type == ContentBlockType.codeBlock;
  }

  ({ContentBlock first, ContentBlock second})? _sliceBlock(
    ContentBlock block,
    double availableWidth,
    double targetHeight,
    ReaderSettings settings,
  ) {
    final spans = block.spans;
    if (spans.isEmpty) return null;

    final fontSize = switch (block.type) {
      ContentBlockType.codeBlock => settings.fontSize * 0.9,
      _ => settings.fontSize,
    };
    final effectiveWidth = block.type == ContentBlockType.blockquote ? availableWidth - 24 : availableWidth;

    final tp = TextPainter(
      text: block.toTextSpan(TextStyle(
        fontFamily: settings.fontFamily,
        fontSize: fontSize,
        fontWeight: settings.fontWeight,
        height: settings.lineHeight,
        letterSpacing: 0.2,
      )),
      textDirection: TextDirection.ltr,
      textAlign: block.textAlign ?? settings.textAlign.value,
    )..layout(maxWidth: effectiveWidth.clamp(1.0, double.infinity));

    final pos = tp.getPositionForOffset(Offset(effectiveWidth, targetHeight));
    int charOffset = pos.offset;

    if (charOffset <= 0 || charOffset >= block.plainText.length) {
      charOffset = (block.plainText.length / 2).round();
    }

    final text = block.plainText;
    int breakIndex = text.lastIndexOf(' ', charOffset);
    if (breakIndex == -1 || breakIndex < (charOffset * 0.4)) {
      breakIndex = charOffset;
    }

    final firstText = text.substring(0, breakIndex).trim();
    final secondText = text.substring(breakIndex).trim();

    if (firstText.isEmpty || secondText.isEmpty) return null;

    final firstBlock = ContentBlock(
      type: block.type,
      spans: [DocInlineSpan(text: firstText)],
      plainText: firstText,
      textAlign: block.textAlign,
    );

    final secondBlock = ContentBlock(
      type: block.type,
      spans: [DocInlineSpan(text: secondText)],
      plainText: secondText,
      textAlign: block.textAlign,
    );

    return (first: firstBlock, second: secondBlock);
  }

  /// Finds the page number containing the given reading position.
  int findPageForPosition(PaginatedChapter chapter, ReadingPosition position) {
    for (int i = 0; i < chapter.pages.length; i++) {
      final page = chapter.pages[i];
      if (position.contentBlockIndex >= page.startBlockIndex &&
          position.contentBlockIndex <= page.endBlockIndex) {
        return i;
      }
    }
    return (chapter.pages.length - 1).clamp(0, chapter.pages.length - 1);
  }

  /// Creates a ReadingPosition from a page index.
  ReadingPosition positionFromPage(PaginatedChapter chapter, int pageIndex, int chapterIndex) {
    if (pageIndex < 0 || pageIndex >= chapter.pages.length) {
      return ReadingPosition(chapterIndex: chapterIndex);
    }
    final page = chapter.pages[pageIndex];
    return ReadingPosition(
      chapterIndex: chapterIndex,
      contentBlockIndex: page.startBlockIndex,
    );
  }

  /// Measures the height of a content block given available width and settings.
  double _measureBlock(ContentBlock block, double availableWidth, ReaderSettings settings) {
    switch (block.type) {
      case ContentBlockType.paragraph:
        return _measureText(block, availableWidth, settings, settings.fontSize);

      case ContentBlockType.heading1:
        return _measureText(block, availableWidth, settings, settings.fontSize + 12) + 8;
      case ContentBlockType.heading2:
        return _measureText(block, availableWidth, settings, settings.fontSize + 8) + 6;
      case ContentBlockType.heading3:
        return _measureText(block, availableWidth, settings, settings.fontSize + 4) + 4;
      case ContentBlockType.heading4:
      case ContentBlockType.heading5:
      case ContentBlockType.heading6:
        return _measureText(block, availableWidth, settings, settings.fontSize + 2) + 2;

      case ContentBlockType.image:
        if (block.imageData != null) {
          final imageWidth = availableWidth * 0.9;
          return imageWidth * 0.75;
        }
        return 0;

      case ContentBlockType.orderedList:
      case ContentBlockType.unorderedList:
        if (block.listItems == null) return 0;
        var height = 0.0;
        for (final item in block.listItems!) {
          final itemText = item.map((s) => s.text).join();
          final tp = TextPainter(
            text: TextSpan(
              text: '  • $itemText',
              style: TextStyle(
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                letterSpacing: 0.2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: availableWidth);
          height += tp.height + 4;
        }
        return height;

      case ContentBlockType.blockquote:
        return _measureText(block, availableWidth - 24, settings, settings.fontSize) + 16;

      case ContentBlockType.horizontalRule:
        return 24;

      case ContentBlockType.codeBlock:
        return _measureText(block, availableWidth - 16, settings, settings.fontSize * 0.9) + 16;
    }
  }

  /// Measures text height using TextPainter.
  double _measureText(
    ContentBlock block,
    double maxWidth,
    ReaderSettings settings,
    double fontSize,
  ) {
    final textSpan = block.toTextSpan(TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: fontSize,
      fontWeight: block.isHeading ? FontWeight.bold : settings.fontWeight,
      height: settings.lineHeight,
      letterSpacing: 0.2,
    ));

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: block.textAlign ?? settings.textAlign.value,
    )..layout(maxWidth: maxWidth.clamp(1, double.infinity));

    return tp.height;
  }

  /// Returns the vertical spacing after a block.
  double _blockSpacing(ContentBlock block, ReaderSettings settings) {
    if (block.isHeading) return settings.paragraphSpacing + 4;
    if (block.type == ContentBlockType.image) return settings.paragraphSpacing;
    if (block.type == ContentBlockType.horizontalRule) return 8;
    return settings.paragraphSpacing;
  }
}
