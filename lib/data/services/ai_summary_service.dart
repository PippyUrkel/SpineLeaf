import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

/// Abstract AI summary service interface
abstract class AiSummaryService {
  Future<ChapterSummary> generateSummary(String bookId, int chapterIndex, String chapterTitle, String chapterContent);
  bool get isAvailable;
}

/// Mock implementation that generates plausible summaries from chapter content
class MockAiSummaryService implements AiSummaryService {
  final Map<String, Map<int, ChapterSummary>> _cache = {};

  @override
  Future<ChapterSummary> generateSummary(
    String bookId,
    int chapterIndex,
    String chapterTitle,
    String chapterContent,
  ) async {
    // Check cache
    if (_cache[bookId]?[chapterIndex] != null) {
      return _cache[bookId]![chapterIndex]!;
    }

    await Future.delayed(const Duration(milliseconds: 800)); // Simulate AI processing

    // Extract some words from content for realistic mock
    final words = chapterContent.split(RegExp(r'\s+')).where((w) => w.length > 4).toList();
    final uniqueWords = words.toSet().take(20).toList();

    // Generate mock summary
    final summary = ChapterSummary(
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      summary: _generateMockSummary(chapterTitle, uniqueWords),
      keyPoints: _generateKeyPoints(chapterTitle, uniqueWords),
      characters: _extractCharacterNames(chapterContent),
      concepts: _extractConcepts(uniqueWords),
      isGenerated: true,
    );

    _cache.putIfAbsent(bookId, () => {});
    _cache[bookId]![chapterIndex] = summary;

    return summary;
  }

  String _generateMockSummary(String title, List<String> words) {
    final templates = [
      'This chapter explores the central themes of $title, delving into the complexities that define the narrative. '
          'The author weaves together multiple perspectives to create a rich tapestry of ideas and emotions.',
      'In "$title," the narrative takes a compelling turn as key events unfold. '
          'The chapter builds tension through carefully constructed scenes that advance the overarching story.',
      '"$title" presents a thoughtful examination of the subjects at hand. '
          'Through vivid prose and nuanced character development, the author illuminates important themes that resonate throughout the work.',
    ];
    return templates[title.length % templates.length];
  }

  List<String> _generateKeyPoints(String title, List<String> words) {
    return [
      'The chapter introduces important developments related to the central theme.',
      'Key relationships between characters are explored and deepened.',
      'New challenges arise that will influence the direction of the story.',
      'The author provides crucial context for understanding later events.',
    ];
  }

  List<String> _extractCharacterNames(String content) {
    // Simple heuristic: find capitalized words that appear multiple times
    final pattern = RegExp(r'\b[A-Z][a-z]{2,}\b');
    final matches = pattern.allMatches(content);
    final names = <String, int>{};
    for (final match in matches) {
      final name = match.group(0)!;
      if (!_commonWords.contains(name.toLowerCase())) {
        names[name] = (names[name] ?? 0) + 1;
      }
    }
    return names.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .take(5)
        .toList();
  }

  List<String> _extractConcepts(List<String> words) {
    return words.take(4).map((w) => w.capitalizeFirst()).toList();
  }

  static const _commonWords = {
    'the', 'and', 'but', 'for', 'not', 'you', 'all', 'can', 'had', 'her',
    'was', 'one', 'our', 'out', 'are', 'has', 'his', 'how', 'its', 'may',
    'new', 'now', 'old', 'see', 'way', 'who', 'did', 'get', 'let', 'say',
    'she', 'too', 'use', 'this', 'that', 'with', 'have', 'from', 'they',
    'been', 'said', 'each', 'which', 'their', 'will', 'other', 'about',
    'many', 'then', 'them', 'some', 'would', 'make', 'like', 'into', 'time',
    'very', 'when', 'come', 'could', 'more', 'after', 'also', 'just', 'than',
    'chapter', 'part', 'section', 'introduction', 'conclusion', 'there',
  };

  @override
  bool get isAvailable => true;
}

extension _StringCap on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

final aiSummaryServiceProvider = Provider<AiSummaryService>((ref) {
  return MockAiSummaryService();
});
