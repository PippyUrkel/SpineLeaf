import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'dictionary_cache.dart';

/// Abstract dictionary service interface
abstract class DictionaryService {
  Future<DictionaryEntry?> define(String word);
  bool get isOfflineAvailable;
}

/// Online dictionary service using the Free Dictionary API (dictionaryapi.dev).
/// No API key required. Caches results locally via DictionaryCache.
class FreeDictionaryService implements DictionaryService {
  static const _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';
  final DictionaryCache _cache = DictionaryCache();
  final http.Client _client;

  FreeDictionaryService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<DictionaryEntry?> define(String word) async {
    final cleanWord = word.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '').toLowerCase().trim();
    if (cleanWord.isEmpty) return null;

    final primary = await _fetchDefinition(cleanWord);
    if (primary != null) return primary;

    // Stemming fallbacks for plurals, past tense, etc.
    final fallbacks = <String>[];
    if (cleanWord.endsWith("'s")) {
      fallbacks.add(cleanWord.substring(0, cleanWord.length - 2));
    }
    if (cleanWord.endsWith("ies") && cleanWord.length > 3) {
      fallbacks.add('${cleanWord.substring(0, cleanWord.length - 3)}y');
    }
    if (cleanWord.endsWith("es") && cleanWord.length > 3) {
      fallbacks.add(cleanWord.substring(0, cleanWord.length - 2));
    }
    if (cleanWord.endsWith("s") && cleanWord.length > 2) {
      fallbacks.add(cleanWord.substring(0, cleanWord.length - 1));
    }
    if (cleanWord.endsWith("ed") && cleanWord.length > 3) {
      fallbacks.add(cleanWord.substring(0, cleanWord.length - 2));
      fallbacks.add(cleanWord.substring(0, cleanWord.length - 1));
    }
    if (cleanWord.endsWith("ing") && cleanWord.length > 4) {
      fallbacks.add(cleanWord.substring(0, cleanWord.length - 3));
      fallbacks.add('${cleanWord.substring(0, cleanWord.length - 3)}e');
    }

    for (final fallback in fallbacks) {
      final res = await _fetchDefinition(fallback);
      if (res != null) return res;
    }

    return null;
  }

  Future<DictionaryEntry?> _fetchDefinition(String word) async {
    final cached = await _cache.get(word);
    if (cached != null) return cached;

    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/$word'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isEmpty) return null;

        final entry = _parseResponse(data);
        if (entry != null) {
          await _cache.put(word, entry);
        }
        return entry;
      }
    } catch (_) {}
    return null;
  }

  DictionaryEntry? _parseResponse(List<dynamic> data) {
    if (data.isEmpty) return null;

    final first = data[0] as Map<String, dynamic>;
    final word = first['word'] as String? ?? '';

    // Extract phonetics
    String? pronunciation;
    String? audioUrl;
    final phonetics = first['phonetics'] as List<dynamic>?;
    if (phonetics != null) {
      for (final p in phonetics) {
        final map = p as Map<String, dynamic>;
        if (pronunciation == null && map['text'] != null) {
          pronunciation = map['text'] as String;
        }
        if (audioUrl == null && map['audio'] != null) {
          final audio = map['audio'] as String;
          if (audio.isNotEmpty) audioUrl = audio;
        }
      }
    }

    // Also check top-level phonetic
    pronunciation ??= first['phonetic'] as String?;

    // Extract meanings
    final definitions = <DictionaryDefinition>[];
    final meanings = first['meanings'] as List<dynamic>?;
    if (meanings != null) {
      for (final meaning in meanings) {
        final map = meaning as Map<String, dynamic>;
        final partOfSpeech = map['partOfSpeech'] as String? ?? '';
        final defs = map['definitions'] as List<dynamic>?;

        // Collect synonyms and antonyms at meaning level
        final meaningSynonyms = (map['synonyms'] as List<dynamic>?)?.cast<String>() ?? [];
        final meaningAntonyms = (map['antonyms'] as List<dynamic>?)?.cast<String>() ?? [];

        if (defs != null) {
          for (final def in defs) {
            final defMap = def as Map<String, dynamic>;
            final definition = defMap['definition'] as String? ?? '';
            final example = defMap['example'] as String?;

            // Combine definition-level and meaning-level synonyms/antonyms
            final defSynonyms = (defMap['synonyms'] as List<dynamic>?)?.cast<String>() ?? [];
            final defAntonyms = (defMap['antonyms'] as List<dynamic>?)?.cast<String>() ?? [];

            final allSynonyms = {...meaningSynonyms, ...defSynonyms}.toList();
            final allAntonyms = {...meaningAntonyms, ...defAntonyms}.toList();

            if (definition.isNotEmpty) {
              definitions.add(DictionaryDefinition(
                partOfSpeech: partOfSpeech,
                definition: definition,
                example: example,
                synonyms: allSynonyms,
                antonyms: allAntonyms,
              ));
            }
          }
        }
      }
    }

    if (definitions.isEmpty) return null;

    return DictionaryEntry(
      word: word,
      pronunciation: pronunciation,
      phoneticAudioUrl: audioUrl,
      definitions: definitions,
    );
  }

  @override
  bool get isOfflineAvailable => false;
}

/// Mock dictionary with common English words — used as fallback
/// when offline and no cache exists.
class MockDictionaryService implements DictionaryService {
  static final Map<String, DictionaryEntry> _dictionary = {
    'eloquent': const DictionaryEntry(
      word: 'eloquent',
      pronunciation: '/ˈel.ə.kwənt/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Fluent or persuasive in speaking or writing.',
          example: 'She gave an eloquent speech that moved the audience to tears.',
        ),
      ],
    ),
    'serendipity': const DictionaryEntry(
      word: 'serendipity',
      pronunciation: '/ˌser.ənˈdɪp.ə.ti/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'The occurrence and development of events by chance in a happy or beneficial way.',
          example: 'A fortunate stroke of serendipity brought them together.',
        ),
      ],
    ),
    'ephemeral': const DictionaryEntry(
      word: 'ephemeral',
      pronunciation: '/ɪˈfem.ər.əl/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Lasting for a very short time.',
          example: 'The ephemeral beauty of the cherry blossoms drew crowds each spring.',
        ),
      ],
    ),
  };

  @override
  Future<DictionaryEntry?> define(String word) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final lower = word.toLowerCase().trim();
    return _dictionary[lower];
  }

  @override
  bool get isOfflineAvailable => true;
}

/// Composite dictionary service: tries online first, falls back to mock/cache.
class CompositeDictionaryService implements DictionaryService {
  final FreeDictionaryService _online;
  final MockDictionaryService _fallback;

  CompositeDictionaryService()
      : _online = FreeDictionaryService(),
        _fallback = MockDictionaryService();

  @override
  Future<DictionaryEntry?> define(String word) async {
    // Try online (which also checks cache)
    final result = await _online.define(word);
    if (result != null) return result;

    // Fall back to mock dictionary
    return _fallback.define(word);
  }

  @override
  bool get isOfflineAvailable => true; // Mock provides some offline words
}

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return CompositeDictionaryService();
});
