// Core constants for the e-book reader application
import 'package:flutter/material.dart';

// Responsive breakpoints
const double kCompactWidth = 600;
const double kMediumWidth = 840;
const double kExpandedWidth = 1200;

// Animation durations
const Duration kFastAnimation = Duration(milliseconds: 200);
const Duration kMediumAnimation = Duration(milliseconds: 350);
const Duration kSlowAnimation = Duration(milliseconds: 500);

// Reader defaults
const double kDefaultFontSize = 18.0;
const double kMinFontSize = 14.0;
const double kMaxFontSize = 36.0;
const double kDefaultLineHeight = 1.6;
const double kMinLineHeight = 1.0;
const double kMaxLineHeight = 3.0;
const double kDefaultParagraphSpacing = 12.0;
const double kDefaultMargin = 24.0;
const double kMinMargin = 8.0;
const double kMaxMargin = 64.0;

// RSVP defaults
const int kDefaultWpm = 300;
const int kMinWpm = 100;
const int kMaxWpm = 1000;
const List<int> kWpmPresets = [200, 300, 400, 500, 600];

// Library layout
const double kBookCoverAspectRatio = 0.67; // ~2:3
const double kGridBookWidth = 140.0;
const int kGridCrossAxisCount = 3;

// Color seeds for theme
const Color kDefaultSeedColor = Color(0xFF6750A4);
const Color kWarmSeedColor = Color(0xFF8B5E3C);
const Color kCoolSeedColor = Color(0xFF1A5276);

// Book statuses
enum BookStatus {
  unread('Unread'),
  reading('Reading'),
  completed('Completed');

  const BookStatus(this.label);
  final String label;
}

// Reading themes
enum ReadingTheme {
  light('Light', Colors.white, Colors.black87, Color(0xFFF5F5F5)),
  sepia('Sepia', Color(0xFFF4ECD8), Color(0xFF5B4636), Color(0xFFE8DCC8)),
  dark('Dark', Color(0xFF1E1E2E), Color(0xFFCDD6F4), Color(0xFF2A2A3C)),
  night('Night', Colors.black, Color(0xFF8B8B8B), Color(0xFF0D0D0D));

  const ReadingTheme(this.label, this.backgroundColor, this.textColor, this.surfaceColor);
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color surfaceColor;
}

// Supported formats
enum BookFormat {
  epub('EPUB', '.epub', 'application/epub+zip'),
  pdf('PDF', '.pdf', 'application/pdf'),
  txt('TXT', '.txt', 'text/plain'),
  rtf('RTF', '.rtf', 'application/rtf'),
  markdown('Markdown', '.md', 'text/markdown'),
  html('HTML', '.html', 'text/html'),
  mobi('MOBI', '.mobi', 'application/x-mobipocket-ebook'),
  azw('AZW', '.azw', 'application/vnd.amazon.ebook'),
  azw3('AZW3', '.azw3', 'application/vnd.amazon.ebook'),
  fb2('FB2', '.fb2', 'text/xml');

  const BookFormat(this.label, this.extension, this.mimeType);
  final String label;
  final String extension;
  final String mimeType;

  static BookFormat? fromExtension(String ext) {
    final lower = ext.toLowerCase();
    for (final format in values) {
      if (format.extension == lower) return format;
    }
    return null;
  }
}

// Sort options
enum LibrarySort {
  recentlyRead('Recently Read'),
  recentlyAdded('Recently Added'),
  title('Title'),
  author('Author'),
  progress('Progress');

  const LibrarySort(this.label);
  final String label;
}

// Text alignment options
enum ReaderTextAlign {
  left('Left', TextAlign.left),
  center('Center', TextAlign.center),
  justify('Justify', TextAlign.justify);

  const ReaderTextAlign(this.label, this.value);
  final String label;
  final TextAlign value;
}

// Annotation types
enum AnnotationType {
  bookmark,
  highlight,
  note,
}

// Highlight colors
const List<Color> kHighlightColors = [
  Color(0x80FFEB3B), // Yellow
  Color(0x8066BB6A), // Green
  Color(0x8042A5F5), // Blue
  Color(0x80EF5350), // Red
  Color(0x80AB47BC), // Purple
  Color(0x80FF7043), // Orange
];
