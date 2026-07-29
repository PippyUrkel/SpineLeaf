import 'package:flutter/material.dart';
import '../../core/constants.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String? publisher;
  final String? isbn;
  final String? filePath;
  final String? coverPath;
  final BookFormat format;
  final int totalChapters;
  final DateTime dateAdded;
  final DateTime? lastOpened;
  final BookStatus status;
  final String? fileHash;
  final int totalWords;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    this.publisher,
    this.isbn,
    this.filePath,
    this.coverPath,
    required this.format,
    this.totalChapters = 0,
    required this.dateAdded,
    this.lastOpened,
    this.status = BookStatus.unread,
    this.fileHash,
    this.totalWords = 0,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    String? publisher,
    String? isbn,
    String? filePath,
    String? coverPath,
    BookFormat? format,
    int? totalChapters,
    DateTime? dateAdded,
    DateTime? lastOpened,
    BookStatus? status,
    String? fileHash,
    int? totalWords,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      publisher: publisher ?? this.publisher,
      isbn: isbn ?? this.isbn,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      format: format ?? this.format,
      totalChapters: totalChapters ?? this.totalChapters,
      dateAdded: dateAdded ?? this.dateAdded,
      lastOpened: lastOpened ?? this.lastOpened,
      status: status ?? this.status,
      fileHash: fileHash ?? this.fileHash,
      totalWords: totalWords ?? this.totalWords,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'description': description,
    'publisher': publisher,
    'isbn': isbn,
    'filePath': filePath,
    'coverPath': coverPath,
    'format': format.index,
    'totalChapters': totalChapters,
    'dateAdded': dateAdded.toIso8601String(),
    'lastOpened': lastOpened?.toIso8601String(),
    'status': status.index,
    'fileHash': fileHash,
    'totalWords': totalWords,
  };

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      description: json['description'] as String?,
      publisher: json['publisher'] as String?,
      isbn: json['isbn'] as String?,
      filePath: json['filePath'] as String?,
      coverPath: json['coverPath'] as String?,
      format: BookFormat.values[(json['format'] as int? ?? 0).clamp(0, BookFormat.values.length - 1)],
      totalChapters: json['totalChapters'] as int? ?? 0,
      dateAdded: DateTime.tryParse(json['dateAdded'] as String? ?? '') ?? DateTime.now(),
      lastOpened: json['lastOpened'] != null ? DateTime.tryParse(json['lastOpened'] as String) : null,
      status: BookStatus.values[(json['status'] as int? ?? 0).clamp(0, BookStatus.values.length - 1)],
      fileHash: json['fileHash'] as String?,
      totalWords: json['totalWords'] as int? ?? 0,
    );
  }
}

class Chapter {
  final String id;
  final String bookId;
  final String title;
  final int index;
  final String content;
  final int wordCount;

  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.index,
    required this.content,
    this.wordCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'title': title,
    'index': index,
    'content': content,
    'wordCount': wordCount,
  };

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      index: json['index'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      wordCount: json['wordCount'] as int? ?? 0,
    );
  }
}

class ReadingProgress {
  final String bookId;
  final int currentChapter;
  final double positionInChapter;
  final double overallPercent;
  final int chaptersCompleted;
  final Set<int> readChapterIndices;
  final int totalReadingTimeSeconds;
  final DateTime? lastReadAt;

  const ReadingProgress({
    required this.bookId,
    this.currentChapter = 0,
    this.positionInChapter = 0.0,
    this.overallPercent = 0.0,
    this.chaptersCompleted = 0,
    this.readChapterIndices = const {},
    this.totalReadingTimeSeconds = 0,
    this.lastReadAt,
  });

  bool isChapterRead(int chapterIndex) {
    return readChapterIndices.contains(chapterIndex) || chapterIndex < chaptersCompleted;
  }

  ReadingProgress copyWith({
    String? bookId,
    int? currentChapter,
    double? positionInChapter,
    double? overallPercent,
    int? chaptersCompleted,
    Set<int>? readChapterIndices,
    int? totalReadingTimeSeconds,
    DateTime? lastReadAt,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      currentChapter: currentChapter ?? this.currentChapter,
      positionInChapter: positionInChapter ?? this.positionInChapter,
      overallPercent: overallPercent ?? this.overallPercent,
      chaptersCompleted: chaptersCompleted ?? this.chaptersCompleted,
      readChapterIndices: readChapterIndices ?? this.readChapterIndices,
      totalReadingTimeSeconds: totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'currentChapter': currentChapter,
    'positionInChapter': positionInChapter,
    'overallPercent': overallPercent,
    'chaptersCompleted': chaptersCompleted,
    'readChapterIndices': readChapterIndices.toList(),
    'totalReadingTimeSeconds': totalReadingTimeSeconds,
    'lastReadAt': lastReadAt?.toIso8601String(),
  };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      bookId: json['bookId'] as String? ?? '',
      currentChapter: json['currentChapter'] as int? ?? 0,
      positionInChapter: (json['positionInChapter'] as num?)?.toDouble() ?? 0.0,
      overallPercent: (json['overallPercent'] as num?)?.toDouble() ?? 0.0,
      chaptersCompleted: json['chaptersCompleted'] as int? ?? 0,
      readChapterIndices: (json['readChapterIndices'] as List<dynamic>?)?.cast<int>().toSet() ?? const {},
      totalReadingTimeSeconds: json['totalReadingTimeSeconds'] as int? ?? 0,
      lastReadAt: json['lastReadAt'] != null ? DateTime.tryParse(json['lastReadAt'] as String) : null,
    );
  }

  Duration get totalReadingTime => Duration(seconds: totalReadingTimeSeconds);
}

class Annotation {
  final String id;
  final String bookId;
  final int chapterIndex;
  final AnnotationType type;
  final String? selectedText;
  final String? note;
  final Color? highlightColor;
  final int position;
  final DateTime createdAt;

  const Annotation({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.type,
    this.selectedText,
    this.note,
    this.highlightColor,
    this.position = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'chapterIndex': chapterIndex,
    'type': type.index,
    'selectedText': selectedText,
    'note': note,
    'highlightColor': highlightColor?.toARGB32(),
    'position': position,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      type: AnnotationType.values[(json['type'] as int? ?? 0).clamp(0, AnnotationType.values.length - 1)],
      selectedText: json['selectedText'] as String?,
      note: json['note'] as String?,
      highlightColor: json['highlightColor'] != null ? Color(json['highlightColor'] as int) : null,
      position: json['position'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ReadingSession {
  final String id;
  final String bookId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int chaptersRead;
  final int wordsRead;

  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.chaptersRead = 0,
    this.wordsRead = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'chaptersRead': chaptersRead,
    'wordsRead': wordsRead,
  };

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      chaptersRead: json['chaptersRead'] as int? ?? 0,
      wordsRead: json['wordsRead'] as int? ?? 0,
    );
  }

  Duration get duration => Duration(seconds: durationSeconds);
}

class ReaderSettings {
  final String fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final double lineHeight;
  final double paragraphSpacing;
  final ReaderTextAlign textAlign;
  final double margin;
  final ReadingTheme readingTheme;
  final bool scrollMode;

  const ReaderSettings({
    this.fontFamily = 'Literata',
    this.fontSize = 18.0,
    this.fontWeight = FontWeight.w400,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 12.0,
    this.textAlign = ReaderTextAlign.left,
    this.margin = 24.0,
    this.readingTheme = ReadingTheme.light,
    this.scrollMode = false,
  });

  ReaderSettings copyWith({
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    double? lineHeight,
    double? paragraphSpacing,
    ReaderTextAlign? textAlign,
    double? margin,
    ReadingTheme? readingTheme,
    bool? scrollMode,
  }) {
    return ReaderSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      textAlign: textAlign ?? this.textAlign,
      margin: margin ?? this.margin,
      readingTheme: readingTheme ?? this.readingTheme,
      scrollMode: scrollMode ?? this.scrollMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'fontWeightIndex': fontWeight.value,
    'lineHeight': lineHeight,
    'paragraphSpacing': paragraphSpacing,
    'textAlign': textAlign.index,
    'margin': margin,
    'readingTheme': readingTheme.index,
    'scrollMode': scrollMode,
  };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontFamily: json['fontFamily'] as String? ?? 'Literata',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      fontWeight: FontWeight.values.firstWhere((w) => w.value == (json['fontWeightIndex'] as int? ?? 400), orElse: () => FontWeight.w400),
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 12.0,
      textAlign: ReaderTextAlign.values[json['textAlign'] as int? ?? 0],
      margin: (json['margin'] as num?)?.toDouble() ?? 24.0,
      readingTheme: ReadingTheme.values[json['readingTheme'] as int? ?? 0],
      scrollMode: json['scrollMode'] as bool? ?? false,
    );
  }
}

class BookWithProgress {
  final Book book;
  final ReadingProgress? progress;

  const BookWithProgress({required this.book, this.progress});

  double get progressPercent => progress?.overallPercent ?? 0.0;
  bool get isReading => book.status == BookStatus.reading;
  bool get isCompleted => book.status == BookStatus.completed;
  bool get isUnread => book.status == BookStatus.unread;
}

class ReadingStats {
  final Duration readingTimeToday;
  final Duration totalReadingTime;
  final int booksCompleted;
  final int booksReading;
  final int totalChaptersRead;
  final int currentStreak;
  final List<DailyReading> recentActivity;

  const ReadingStats({
    this.readingTimeToday = Duration.zero,
    this.totalReadingTime = Duration.zero,
    this.booksCompleted = 0,
    this.booksReading = 0,
    this.totalChaptersRead = 0,
    this.currentStreak = 0,
    this.recentActivity = const [],
  });
}

class DailyReading {
  final DateTime date;
  final Duration readingTime;
  final int chaptersRead;

  const DailyReading({
    required this.date,
    this.readingTime = Duration.zero,
    this.chaptersRead = 0,
  });
}

class ChapterSummary {
  final int chapterIndex;
  final String chapterTitle;
  final String summary;
  final List<String> keyPoints;
  final List<String> characters;
  final List<String> concepts;
  final bool isGenerated;

  const ChapterSummary({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.summary,
    this.keyPoints = const [],
    this.characters = const [],
    this.concepts = const [],
    this.isGenerated = false,
  });
}

class DictionaryEntry {
  final String word;
  final String? pronunciation;
  final String? phoneticAudioUrl;
  final List<DictionaryDefinition> definitions;

  const DictionaryEntry({
    required this.word,
    this.pronunciation,
    this.phoneticAudioUrl,
    this.definitions = const [],
  });
}

class DictionaryDefinition {
  final String partOfSpeech;
  final String definition;
  final String? example;
  final List<String> synonyms;
  final List<String> antonyms;

  const DictionaryDefinition({
    required this.partOfSpeech,
    required this.definition,
    this.example,
    this.synonyms = const [],
    this.antonyms = const [],
  });
}

class SearchResult {
  final String bookId;
  final int chapterIndex;
  final String chapterTitle;
  final String excerpt;
  final int position;

  const SearchResult({
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.excerpt,
    this.position = 0,
  });
}
