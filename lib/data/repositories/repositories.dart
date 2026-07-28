import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../../core/constants.dart';

/// In-memory book repository with SharedPreferences persistence for progress
class BookRepository {
  final List<Book> _books = [];
  final Map<String, List<Chapter>> _chapters = {};
  final Map<String, ReadingProgress> _progress = {};
  final List<Annotation> _annotations = [];
  final List<ReadingSession> _sessions = [];

  List<Book> get allBooks => List.unmodifiable(_books);

  void addBook(Book book) {
    _books.add(book);
  }

  void addChapters(String bookId, List<Chapter> chapters) {
    _chapters[bookId] = chapters;
  }

  void removeBook(String bookId) {
    _books.removeWhere((b) => b.id == bookId);
    _chapters.remove(bookId);
    _progress.remove(bookId);
    _annotations.removeWhere((a) => a.bookId == bookId);
    _sessions.removeWhere((s) => s.bookId == bookId);
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
        updateBook(book.copyWith(
          status: newStatus,
          lastOpened: DateTime.now(),
        ));
      }
    }
  }

  void setBookStatus(String bookId, BookStatus status) {
    final book = getBook(bookId);
    if (book != null) {
      updateBook(book.copyWith(status: status));
      if (status == BookStatus.completed) {
        final prog = getProgress(bookId);
        updateProgress(prog.copyWith(overallPercent: 1.0));
      } else if (status == BookStatus.unread) {
        updateProgress(ReadingProgress(bookId: bookId));
      }
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
  }

  void removeAnnotation(String annotationId) {
    _annotations.removeWhere((a) => a.id == annotationId);
  }

  // Sessions
  void addSession(ReadingSession session) {
    _sessions.add(session);
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

  ReaderSettings _settings = const ReaderSettings();
  ReaderSettings get settings => _settings;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Color _seedColor = kDefaultSeedColor;
  Color get seedColor => _seedColor;

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
}

// Riverpod providers
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository();
});
