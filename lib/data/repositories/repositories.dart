import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../../core/constants.dart';

/// Book repository with JSON file persistence for books, chapters, progress, annotations, and sessions
class BookRepository {
  final List<Book> _books = [];
  final Map<String, List<Chapter>> _chapters = {};
  final Map<String, ReadingProgress> _progress = {};
  final List<Annotation> _annotations = [];
  final List<ReadingSession> _sessions = [];
  bool _loaded = false;

  List<Book> get allBooks => List.unmodifiable(_books);

  Future<Directory> _getAppDir() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final appDir = await _getAppDir();

      // Load Books
      final booksFile = File('${appDir.path}/spineleaf_books.json');
      if (await booksFile.exists()) {
        final content = await booksFile.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _books.clear();
        for (final item in list) {
          _books.add(Book.fromJson(item as Map<String, dynamic>));
        }
      }

      // Load Chapters for each book
      for (final book in _books) {
        final chaptersFile = File('${appDir.path}/chapters_${book.id}.json');
        if (await chaptersFile.exists()) {
          final content = await chaptersFile.readAsString();
          final List<dynamic> list = jsonDecode(content);
          final chaptersList = list.map((c) => Chapter.fromJson(c as Map<String, dynamic>)).toList();
          _chapters[book.id] = chaptersList;
        }
      }

      // Load Progress
      final progressFile = File('${appDir.path}/spineleaf_progress.json');
      if (await progressFile.exists()) {
        final content = await progressFile.readAsString();
        final Map<String, dynamic> map = jsonDecode(content);
        _progress.clear();
        map.forEach((key, val) {
          _progress[key] = ReadingProgress.fromJson(val as Map<String, dynamic>);
        });
      }

      // Load Annotations
      final annotationsFile = File('${appDir.path}/spineleaf_annotations.json');
      if (await annotationsFile.exists()) {
        final content = await annotationsFile.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _annotations.clear();
        for (final item in list) {
          _annotations.add(Annotation.fromJson(item as Map<String, dynamic>));
        }
      }

      // Load Sessions
      final sessionsFile = File('${appDir.path}/spineleaf_sessions.json');
      if (await sessionsFile.exists()) {
        final content = await sessionsFile.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _sessions.clear();
        for (final item in list) {
          _sessions.add(ReadingSession.fromJson(item as Map<String, dynamic>));
        }
      }

      _loaded = true;
    } catch (_) {}
  }

  Future<void> saveToDisk() async {
    try {
      final appDir = await _getAppDir();

      // Save Books
      final booksFile = File('${appDir.path}/spineleaf_books.json');
      await booksFile.writeAsString(jsonEncode(_books.map((b) => b.toJson()).toList()));

      // Save Progress
      final progressFile = File('${appDir.path}/spineleaf_progress.json');
      final progressMap = _progress.map((k, v) => MapEntry(k, v.toJson()));
      await progressFile.writeAsString(jsonEncode(progressMap));

      // Save Annotations
      final annotationsFile = File('${appDir.path}/spineleaf_annotations.json');
      await annotationsFile.writeAsString(jsonEncode(_annotations.map((a) => a.toJson()).toList()));

      // Save Sessions
      final sessionsFile = File('${appDir.path}/spineleaf_sessions.json');
      await sessionsFile.writeAsString(jsonEncode(_sessions.map((s) => s.toJson()).toList()));
    } catch (_) {}
  }

  void addBook(Book book) {
    _books.removeWhere((b) => b.id == book.id);
    _books.add(book);
    saveToDisk();
  }

  void addChapters(String bookId, List<Chapter> chapters) async {
    _chapters[bookId] = chapters;
    try {
      final appDir = await _getAppDir();
      final chaptersFile = File('${appDir.path}/chapters_$bookId.json');
      await chaptersFile.writeAsString(jsonEncode(chapters.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  void removeBook(String bookId) async {
    _books.removeWhere((b) => b.id == bookId);
    _chapters.remove(bookId);
    _progress.remove(bookId);
    _annotations.removeWhere((a) => a.bookId == bookId);
    _sessions.removeWhere((s) => s.bookId == bookId);

    try {
      final appDir = await _getAppDir();
      final chaptersFile = File('${appDir.path}/chapters_$bookId.json');
      if (await chaptersFile.exists()) {
        await chaptersFile.delete();
      }
    } catch (_) {}

    saveToDisk();
  }

  Book? getBook(String bookId) {
    try {
      return _books.firstWhere((b) => b.id == bookId);
    } catch (_) {
      return null;
    }
  }

  void updateBook(Book book) {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index >= 0) _books[index] = book;
    saveToDisk();
  }

  List<Chapter> getChapters(String bookId) {
    return _chapters[bookId] ?? [];
  }

  Chapter? getChapter(String bookId, int index) {
    final chapters = getChapters(bookId);
    if (index >= 0 && index < chapters.length) return chapters[index];
    return null;
  }

  // Progress
  ReadingProgress getProgress(String bookId) {
    return _progress[bookId] ?? ReadingProgress(bookId: bookId);
  }

  void saveProgress(ReadingProgress progress) {
    updateProgress(progress);
  }

  void updateProgress(ReadingProgress progress) {
    _progress[progress.bookId] = progress;
    // Also update book status
    final book = getBook(progress.bookId);
    if (book != null) {
      BookStatus newStatus = book.status;
      if (progress.overallPercent >= 1.0) {
        newStatus = BookStatus.completed;
      } else if (progress.overallPercent > 0) {
        newStatus = BookStatus.reading;
      }
      if (newStatus != book.status) {
        final index = _books.indexWhere((b) => b.id == book.id);
        if (index >= 0) {
          _books[index] = book.copyWith(
            status: newStatus,
            lastOpened: DateTime.now(),
          );
        }
      }
    }
    saveToDisk();
  }

  void setBookStatus(String bookId, BookStatus status) {
    final book = getBook(bookId);
    if (book != null) {
      updateBook(book.copyWith(status: status));
      final chapters = getChapters(bookId);
      if (status == BookStatus.completed) {
        final prog = getProgress(bookId);
        final allIndices = Set<int>.from(List.generate(chapters.length, (i) => i));
        updateProgress(prog.copyWith(
          overallPercent: 1.0,
          chaptersCompleted: chapters.length,
          readChapterIndices: allIndices,
        ));
      } else if (status == BookStatus.unread) {
        updateProgress(ReadingProgress(bookId: bookId));
      }
    }
  }

  void markChaptersRead(String bookId, Iterable<int> chapterIndices) {
    final chapters = getChapters(bookId);
    final totalChapters = chapters.isNotEmpty ? chapters.length : 1;
    final prog = getProgress(bookId);
    final updatedRead = Set<int>.from(prog.readChapterIndices);

    for (int i = 0; i < prog.chaptersCompleted; i++) {
      updatedRead.add(i);
    }
    updatedRead.addAll(chapterIndices);

    final overallPercent = (updatedRead.length / totalChapters).clamp(0.0, 1.0);
    updateProgress(prog.copyWith(
      readChapterIndices: updatedRead,
      chaptersCompleted: updatedRead.length,
      overallPercent: overallPercent,
      lastReadAt: DateTime.now(),
    ));
  }

  void markChaptersUnread(String bookId, Iterable<int> chapterIndices) {
    final chapters = getChapters(bookId);
    final totalChapters = chapters.isNotEmpty ? chapters.length : 1;
    final prog = getProgress(bookId);
    final updatedRead = Set<int>.from(prog.readChapterIndices);

    for (int i = 0; i < prog.chaptersCompleted; i++) {
      updatedRead.add(i);
    }
    updatedRead.removeAll(chapterIndices);

    final overallPercent = (updatedRead.length / totalChapters).clamp(0.0, 1.0);
    updateProgress(prog.copyWith(
      readChapterIndices: updatedRead,
      chaptersCompleted: updatedRead.length,
      overallPercent: overallPercent,
      lastReadAt: DateTime.now(),
    ));
  }

  void toggleChapterRead(String bookId, int chapterIndex) {
    final prog = getProgress(bookId);
    if (prog.isChapterRead(chapterIndex)) {
      markChaptersUnread(bookId, [chapterIndex]);
    } else {
      markChaptersRead(bookId, [chapterIndex]);
    }
  }

  // Annotations
  List<Annotation> getAnnotations(String bookId) {
    return _annotations.where((a) => a.bookId == bookId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<Annotation> getBookmarks(String bookId) {
    return getAnnotations(bookId)
        .where((a) => a.type == AnnotationType.bookmark)
        .toList();
  }

  List<Annotation> getHighlights(String bookId) {
    return getAnnotations(bookId)
        .where((a) => a.type == AnnotationType.highlight)
        .toList();
  }

  List<Annotation> getNotes(String bookId) {
    return getAnnotations(bookId)
        .where((a) => a.type == AnnotationType.note)
        .toList();
  }

  void addAnnotation(Annotation annotation) {
    _annotations.add(annotation);
    saveToDisk();
  }

  void removeAnnotation(String annotationId) {
    _annotations.removeWhere((a) => a.id == annotationId);
    saveToDisk();
  }

  // Sessions
  void addSession(ReadingSession session) {
    _sessions.add(session);
    saveToDisk();
  }

  List<ReadingSession> getSessions({String? bookId, DateTime? since}) {
    var sessions = _sessions.toList();
    if (bookId != null) {
      sessions = sessions.where((s) => s.bookId == bookId).toList();
    }
    if (since != null) {
      sessions = sessions.where((s) => s.startedAt.isAfter(since)).toList();
    }
    return sessions;
  }

  // Sorting and filtering
  List<BookWithProgress> getBooksWithProgress({
    LibrarySort sort = LibrarySort.recentlyRead,
    BookStatus? filterStatus,
    String? searchQuery,
  }) {
    var books = _books.map((b) {
      return BookWithProgress(book: b, progress: _progress[b.id]);
    }).toList();

    // Filter by status
    if (filterStatus != null) {
      books = books.where((bp) => bp.book.status == filterStatus).toList();
    }

    // Search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      books = books.where((bp) {
        return bp.book.title.toLowerCase().contains(query) ||
            bp.book.author.toLowerCase().contains(query);
      }).toList();
    }

    // Sort
    switch (sort) {
      case LibrarySort.recentlyRead:
        books.sort((a, b) {
          final aTime = a.book.lastOpened ?? a.book.dateAdded;
          final bTime = b.book.lastOpened ?? b.book.dateAdded;
          return bTime.compareTo(aTime);
        });
      case LibrarySort.recentlyAdded:
        books.sort((a, b) => b.book.dateAdded.compareTo(a.book.dateAdded));
      case LibrarySort.title:
        books.sort((a, b) => a.book.title.compareTo(b.book.title));
      case LibrarySort.author:
        books.sort((a, b) => a.book.author.compareTo(b.book.author));
      case LibrarySort.progress:
        books.sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    }

    return books;
  }

  BookWithProgress? getMostRecentlyRead() {
    final reading = _books.where((b) => b.status == BookStatus.reading).toList();
    if (reading.isEmpty) return null;
    reading.sort((a, b) {
      final aTime = a.lastOpened ?? a.dateAdded;
      final bTime = b.lastOpened ?? b.dateAdded;
      return bTime.compareTo(aTime);
    });
    final book = reading.first;
    return BookWithProgress(book: book, progress: _progress[book.id]);
  }

  // Statistics
  ReadingStats getStats() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);


    // Today's reading
    final todaySessions = _sessions
        .where((s) => s.startedAt.isAfter(todayStart))
        .toList();
    final todaySeconds = todaySessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

    // Total reading
    final totalSeconds = _sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

    // Books counts
    final completed = _books.where((b) => b.status == BookStatus.completed).length;
    final reading = _books.where((b) => b.status == BookStatus.reading).length;

    // Chapters read
    final totalChaptersRead = _progress.values.fold<int>(0, (sum, p) => sum + p.chaptersCompleted);

    // Reading streak
    int streak = 0;
    var checkDate = todayStart;
    for (int i = 0; i < 365; i++) {
      final dayStart = checkDate.subtract(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      final hasSession = _sessions.any(
        (s) => s.startedAt.isAfter(dayStart) && s.startedAt.isBefore(dayEnd),
      );
      if (hasSession || (i == 0 && todaySessions.isEmpty)) {
        if (hasSession) streak++;
      } else if (i > 0) {
        break;
      }
    }

    // Recent activity (last 7 days)
    final recentActivity = <DailyReading>[];
    for (int i = 6; i >= 0; i--) {
      final dayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      final daySessions = _sessions.where(
        (s) => s.startedAt.isAfter(dayStart) && s.startedAt.isBefore(dayEnd),
      ).toList();
      final daySeconds = daySessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
      final dayChapters = daySessions.fold<int>(0, (sum, s) => sum + s.chaptersRead);
      recentActivity.add(DailyReading(
        date: dayStart,
        readingTime: Duration(seconds: daySeconds),
        chaptersRead: dayChapters,
      ));
    }

    return ReadingStats(
      readingTimeToday: Duration(seconds: todaySeconds),
      totalReadingTime: Duration(seconds: totalSeconds),
      booksCompleted: completed,
      booksReading: reading,
      totalChaptersRead: totalChaptersRead,
      currentStreak: streak,
      recentActivity: recentActivity,
    );
  }

  // Search inside book
  List<SearchResult> searchInBook(String bookId, String query) {
    final chapters = getChapters(bookId);
    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (final chapter in chapters) {
      final content = chapter.content.toLowerCase();
      int startIndex = 0;
      while (true) {
        final index = content.indexOf(lowerQuery, startIndex);
        if (index == -1) break;

        // Extract excerpt
        final excerptStart = (index - 40).clamp(0, content.length);
        final excerptEnd = (index + query.length + 40).clamp(0, content.length);
        final excerpt = '...${chapter.content.substring(excerptStart, excerptEnd)}...';

        results.add(SearchResult(
          bookId: bookId,
          chapterIndex: chapter.index,
          chapterTitle: chapter.title,
          excerpt: excerpt,
          position: index,
        ));

        startIndex = index + 1;
        if (results.length > 50) break;
      }
      if (results.length > 50) break;
    }

    return results;
  }
}

/// Reader settings persistence via SharedPreferences
class PreferencesRepository {
  static const _settingsKey = 'reader_settings';
  static const _themeModeKey = 'theme_mode';
  static const _colorSeedKey = 'color_seed';
  static const _welcomeBookletSeededKey = 'has_seeded_welcome_booklet';

  ReaderSettings _settings = const ReaderSettings();
  ReaderSettings get settings => _settings;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Color _seedColor = kDefaultSeedColor;
  Color get seedColor => _seedColor;

  bool _hasSeededWelcomeBooklet = false;
  bool get hasSeededWelcomeBooklet => _hasSeededWelcomeBooklet;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Reader settings
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        _settings = ReaderSettings.fromJson(jsonDecode(settingsJson));
      } catch (_) {}
    }

    // Theme mode
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // Color seed
    final colorValue = prefs.getInt(_colorSeedKey);
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }

    // Welcome booklet flag
    _hasSeededWelcomeBooklet = prefs.getBool(_welcomeBookletSeededKey) ?? false;
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> saveSeedColor(Color color) async {
    _seedColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorSeedKey, color.toARGB32());
  }

  Future<void> saveWelcomeBookletSeeded(bool seeded) async {
    _hasSeededWelcomeBooklet = seeded;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeBookletSeededKey, seeded);
  }
}

// Riverpod providers
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository();
});
