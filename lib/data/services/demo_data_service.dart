import '../../core/constants.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Service responsible for seeding the friendly welcome booklet on first launch
class DemoDataService {
  static void seedWelcomeBooklet(BookRepository repo) {
    final now = DateTime.now();

    final chapters = [
      Chapter(
        id: 'welcome_ch_0',
        bookId: 'welcome-booklet',
        title: '1. Welcome & Gesture Guide',
        index: 0,
        content: _chapter1Content,
        wordCount: _countWords(_chapter1Content),
      ),
      Chapter(
        id: 'welcome_ch_1',
        bookId: 'welcome-booklet',
        title: '2. Multi-Format Reading Experience',
        index: 1,
        content: _chapter2Content,
        wordCount: _countWords(_chapter2Content),
      ),
      Chapter(
        id: 'welcome_ch_2',
        bookId: 'welcome-booklet',
        title: '3. Built-In Dictionary & Annotations',
        index: 2,
        content: _chapter3Content,
        wordCount: _countWords(_chapter3Content),
      ),
      Chapter(
        id: 'welcome_ch_3',
        bookId: 'welcome-booklet',
        title: '4. Chapter Progress & Batch Actions',
        index: 3,
        content: _chapter4Content,
        wordCount: _countWords(_chapter4Content),
      ),
    ];

    final totalWords = chapters.fold<int>(0, (sum, c) => sum + c.wordCount);

    final book = Book(
      id: 'welcome-booklet',
      title: 'Welcome to SpineLeaf',
      author: 'SpineLeaf Team',
      description: 'A friendly guide to reading, navigating, using gestures, and exploring your e-book reader.',
      publisher: 'SpineLeaf Press',
      format: BookFormat.txt,
      totalChapters: chapters.length,
      dateAdded: now,
      status: BookStatus.reading,
      totalWords: totalWords,
    );

    repo.addBook(book);
    repo.addChapters(book.id, chapters);

    repo.updateProgress(ReadingProgress(
      bookId: book.id,
      currentChapter: 0,
      positionInChapter: 0.0,
      overallPercent: 0.0,
      chaptersCompleted: 0,
      lastReadAt: now,
    ));
  }

  static int _countWords(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  static const String _chapter1Content = '''
Welcome to SpineLeaf, your modern e-book reader designed for comfort, clarity, and control!

Reading Modes:
• Paginated Mode (Default): Offers an authentic book-like experience where text automatically divides into pages calculated for your device's screen size. Flip pages effortlessly with swipe gestures or side-taps.
• Continuous Scroll Mode: Prefer scrolling endlessly? Switch to Scroll Mode anytime in Reader Settings.

Essential Touch Gestures:
• Center Tap: Tap the middle of the screen while reading to show or hide top & bottom navigation controls.
• Side Taps: Tap the left third of the screen to go to the previous page; tap the right third to advance to the next page.
• Horizontal Swipe: Drag horizontally across the screen to turn pages smoothly.
• Pinch to Resize Font: Pinch with two fingers directly on the text surface to instantly increase or decrease font size.
''';

  static const String _chapter2Content = '''
SpineLeaf supports multiple document formats tailored for reflowable and fixed-layout reading:

EPUB Books:
• Full HTML structure support including headings, paragraph spacing, blockquotes, ordered/unordered lists, code snippets, and inline formatting.
• Embedded Images are extracted and rendered seamlessly within paginated pages.

PDF Documents:
• Native PDF rendering powered by pdfrx.
• Supports multi-touch pinch-zoom, panning, page-jump controls, and page indicator overlays.

RTF & Text Files:
• Custom Rich Text Format (RTF) engine for importing external documents with bold, italic, alignment, and formatting intact.
• Plain text and Markdown (.txt, .md) importing.
''';

  static const String _chapter3Content = '''
Integrated Free Dictionary:
• Highlight any word or short phrase in reflowable documents and tap "Define" in the popup selection menu.
• Live online lookups powered by Free Dictionary API with phonetic transcriptions, part-of-speech badges, definitions, examples, synonyms, and antonyms.
• Offline Caching automatically saves looked-up definitions to SharedPreferences so you can revisit them anytime without internet access.

Annotations & Bookmarks:
• Tap the Bookmark icon in the top control bar to save your current location.
• Highlight key passages or add notes to remember important insights.
''';

  static const String _chapter4Content = '''
Chapter Selection & Progress Management:

• Read Chapters Are Greyed Out: In the Table of Contents, any chapter you have already read is automatically greyed out so you can instantly see where you left off.
• Mark or Unmark Single Chapters: Tap the action icon on any chapter item in the Table of Contents to mark it as read or unread.
• Batch Selection Mode: Long-press any chapter in the Table of Contents to activate Batch Selection Mode. Checkboxes will appear alongside each chapter, allowing you to select multiple chapters at once and batch mark them as Read or Unread!

Enjoy your reading journey with SpineLeaf!
''';
}
