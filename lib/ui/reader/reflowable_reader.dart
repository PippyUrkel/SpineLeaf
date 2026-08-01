import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../domain/models/structured_document.dart';
import '../../data/models/models.dart';

/// Renders a list of ContentBlocks as real Flutter widgets.
/// Used by both paginated and scroll modes.
class ContentBlockRenderer extends StatelessWidget {
  final List<ContentBlock> blocks;
  final ReaderSettings settings;
  final ReadingTheme readingTheme;
  final Map<String, Uint8List> images;
  final void Function(String word)? onWordLookup;

  const ContentBlockRenderer({
    super.key,
    required this.blocks,
    required this.settings,
    required this.readingTheme,
    this.images = const {},
    this.onWordLookup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) => _buildBlock(context, block)).toList(),
    );
  }

  Widget _buildBlock(BuildContext context, ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.paragraph:
        return _buildParagraph(context, block);

      case ContentBlockType.heading1:
      case ContentBlockType.heading2:
      case ContentBlockType.heading3:
      case ContentBlockType.heading4:
      case ContentBlockType.heading5:
      case ContentBlockType.heading6:
        return _buildHeading(context, block);

      case ContentBlockType.image:
        return _buildImage(context, block);

      case ContentBlockType.orderedList:
        return _buildList(context, block, ordered: true);

      case ContentBlockType.unorderedList:
        return _buildList(context, block, ordered: false);

      case ContentBlockType.blockquote:
        return _buildBlockquote(context, block);

      case ContentBlockType.horizontalRule:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
          child: Divider(
            color: readingTheme.textColor.withValues(alpha: 0.2),
            thickness: 1,
          ),
        );

      case ContentBlockType.codeBlock:
        return _buildCodeBlock(context, block);
    }
  }

  Widget _buildParagraph(BuildContext context, ContentBlock block) {
    final baseStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      fontWeight: settings.fontWeight,
      height: settings.lineHeight,
      color: readingTheme.textColor,
      letterSpacing: 0.2,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
      child: SelectableText.rich(
        block.toTextSpan(baseStyle),
        textAlign: block.textAlign ?? settings.textAlign.value,
        contextMenuBuilder: _contextMenuBuilder,
      ),
    );
  }

  Widget _buildHeading(BuildContext context, ContentBlock block) {
    final sizeAddition = switch (block.headingLevel) {
      1 => 12.0,
      2 => 8.0,
      3 => 4.0,
      _ => 2.0,
    };

    final baseStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize + sizeAddition,
      fontWeight: FontWeight.bold,
      height: 1.3,
      color: readingTheme.textColor,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: settings.paragraphSpacing * 0.5,
        bottom: settings.paragraphSpacing + 4,
      ),
      child: SelectableText.rich(
        block.toTextSpan(baseStyle),
        contextMenuBuilder: _contextMenuBuilder,
      ),
    );
  }

  Widget _buildImage(BuildContext context, ContentBlock block) {
    Widget imageWidget;

    if (block.imageData != null) {
      imageWidget = Image.memory(
        block.imageData!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imageFallback(block.imageAlt),
      );
    } else if (block.imageSrc != null) {
      final src = block.imageSrc!;
      final decodedSrc = Uri.decodeFull(src);
      final filename = src.split('/').last;

      final bytes = images[src] ??
          images[decodedSrc] ??
          images[filename] ??
          images[filename.toLowerCase()] ??
          images[src.replaceAll('../', '')];

      if (bytes != null) {
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _imageFallback(block.imageAlt),
        );
      } else {
        imageWidget = _imageFallback(block.imageAlt);
      }
    } else {
      imageWidget = _imageFallback(block.imageAlt);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: settings.paragraphSpacing),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _imageFallback(String? alt) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: readingTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, color: readingTheme.textColor.withValues(alpha: 0.3)),
            if (alt != null && alt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  alt,
                  style: TextStyle(
                    color: readingTheme.textColor.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, ContentBlock block, {required bool ordered}) {
    if (block.listItems == null || block.listItems!.isEmpty) return const SizedBox.shrink();

    final baseStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      fontWeight: settings.fontWeight,
      height: settings.lineHeight,
      color: readingTheme.textColor,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        bottom: settings.paragraphSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(block.listItems!.length, (i) {
          final item = block.listItems![i];
          final bullet = ordered ? '${i + 1}.' : '•';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ordered ? 28 : 20,
                  child: Text(
                    bullet,
                    style: baseStyle.copyWith(
                      color: readingTheme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText.rich(
                    TextSpan(
                      children: item.map((span) {
                        return TextSpan(
                          text: span.text,
                          style: span.toTextStyle(baseStyle),
                        );
                      }).toList(),
                    ),
                    contextMenuBuilder: _contextMenuBuilder,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBlockquote(BuildContext context, ContentBlock block) {
    final baseStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      fontWeight: settings.fontWeight,
      fontStyle: FontStyle.italic,
      height: settings.lineHeight,
      color: readingTheme.textColor.withValues(alpha: 0.8),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: readingTheme.textColor.withValues(alpha: 0.3),
              width: 3,
            ),
          ),
        ),
        child: SelectableText.rich(
          block.toTextSpan(baseStyle),
          contextMenuBuilder: _contextMenuBuilder,
        ),
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, ContentBlock block) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: settings.fontSize * 0.9,
      height: settings.lineHeight,
      color: readingTheme.textColor,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: settings.paragraphSpacing),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: readingTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText.rich(
            block.toTextSpan(baseStyle),
            contextMenuBuilder: _contextMenuBuilder,
          ),
        ),
      ),
    );
  }

  Widget _contextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    final selectedText = selection.textInside(text).trim();

    return AdaptiveTextSelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      children: [
        if (selectedText.isNotEmpty && selectedText.split(' ').length <= 3 && onWordLookup != null)
          TextButton.icon(
            onPressed: () {
              editableTextState.hideToolbar();
              onWordLookup!(selectedText);
            },
            icon: const Icon(Icons.book, size: 16),
            label: const Text('Define', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        if (selectedText.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              editableTextState.copySelection(SelectionChangedCause.toolbar);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
      ],
    );
  }
}
