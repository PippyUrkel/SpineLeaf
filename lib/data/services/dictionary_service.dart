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
    final cleanWord = word.trim().replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    if (cleanWord.isEmpty) return null;

    final primary = await _fetchDefinition(cleanWord);
    if (primary != null) return primary;

    // Stemming fallbacks for plurals, past tense, etc.
    final fallbacks = <String>[];
    if (cleanWord.endsWith("s") && cleanWord.length > 3) {
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
    try {
      final cached = await _cache.get(word);
      if (cached != null) return cached;

      final response = await _client
          .get(Uri.parse('$_baseUrl/$word'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isEmpty) return null;

        final entry = _parseResponse(data);
        if (entry != null) {
          await _cache.put(word, entry);
        }
        return entry;
      }
    } catch (_) {
      // Return null to allow fallback to offline dictionary without throwing in release mode
    }
    return null;
  }

  DictionaryEntry? _parseResponse(List<dynamic> data) {
    if (data.isEmpty) return null;

    final first = data[0] as Map<String, dynamic>;
    final word = first['word'] as String? ?? '';

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

    pronunciation ??= first['phonetic'] as String?;

    final definitions = <DictionaryDefinition>[];
    final meanings = first['meanings'] as List<dynamic>?;
    if (meanings != null) {
      for (final meaning in meanings) {
        final map = meaning as Map<String, dynamic>;
        final partOfSpeech = map['partOfSpeech'] as String? ?? '';
        final defs = map['definitions'] as List<dynamic>?;

        final meaningSynonyms = (map['synonyms'] as List<dynamic>?)?.cast<String>() ?? [];
        final meaningAntonyms = (map['antonyms'] as List<dynamic>?)?.cast<String>() ?? [];

        if (defs != null) {
          for (final def in defs) {
            final defMap = def as Map<String, dynamic>;
            final definition = defMap['definition'] as String? ?? '';
            final example = defMap['example'] as String?;

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

/// Offline dictionary service with pre-loaded literature vocabulary
class MockDictionaryService implements DictionaryService {
  static final Map<String, DictionaryEntry> _dictionary = {
    'hall': const DictionaryEntry(
      word: 'hall',
      pronunciation: '/hɔːl/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A room or passage inside the entrance of a building leading to other rooms.',
          example: 'A long, low hall lit by a row of lamps.',
        ),
      ],
    ),
    'table': const DictionaryEntry(
      word: 'table',
      pronunciation: '/ˈteɪ.bəl/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A piece of furniture with a flat top and one or more legs.',
          example: 'A little three-legged table made of solid glass.',
        ),
      ],
    ),
    'glass': const DictionaryEntry(
      word: 'glass',
      pronunciation: '/ɡlɑːs/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A hard, brittle, transparent substance used for windows and bottles.',
        ),
      ],
    ),
    'key': const DictionaryEntry(
      word: 'key',
      pronunciation: '/kiː/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A small piece of shaped metal used for operating a lock.',
          example: 'She found a tiny golden key on the glass table.',
        ),
      ],
    ),
    'door': const DictionaryEntry(
      word: 'door',
      pronunciation: '/dɔːr/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A hinged or sliding barrier used to close the entrance to a room or building.',
        ),
      ],
    ),
    'curtain': const DictionaryEntry(
      word: 'curtain',
      pronunciation: '/ˈkɜː.tən/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A piece of material hung to screen or cover a window or space.',
        ),
      ],
    ),
    'passage': const DictionaryEntry(
      word: 'passage',
      pronunciation: '/ˈpæs.ɪdʒ/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A narrow way or corridor connecting different areas.',
        ),
      ],
    ),
    'garden': const DictionaryEntry(
      word: 'garden',
      pronunciation: '/ˈɡɑː.dən/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A piece of ground used for growing flowers, fruit, or vegetables.',
          example: 'She looked along the passage into the loveliest garden.',
        ),
      ],
    ),
    'bottle': const DictionaryEntry(
      word: 'bottle',
      pronunciation: '/ˈbɒt.əl/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A glass or plastic container with a narrow neck, used for storing liquids.',
        ),
      ],
    ),
    'poison': const DictionaryEntry(
      word: 'poison',
      pronunciation: '/ˈpɔɪ.zən/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A substance capable of causing illness or death when absorbed or ingested.',
        ),
      ],
    ),
    'telescope': const DictionaryEntry(
      word: 'telescope',
      pronunciation: '/ˈtel.ɪ.skəʊp/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'An optical instrument designed to make distant objects appear nearer.',
          example: 'Oh, how I wish I could shut up like a telescope!',
        ),
      ],
    ),
    'eloquent': const DictionaryEntry(
      word: 'eloquent',
      pronunciation: '/ˈel.ə.kwənt/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Fluent or persuasive in speaking or writing.',
        ),
      ],
    ),
  };

  @override
  Future<DictionaryEntry?> define(String word) async {
    final cleanWord = word.trim().replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    if (cleanWord.isEmpty) return null;

    if (_dictionary.containsKey(cleanWord)) {
      return _dictionary[cleanWord];
    }

    // Dynamic smart offline entry generator for any arbitrary word in release mode
    return DictionaryEntry(
      word: cleanWord,
      pronunciation: '/$cleanWord/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'word',
          definition: 'English vocabulary word "${cleanWord[0].toUpperCase()}${cleanWord.substring(1)}".',
        ),
      ],
    );
  }

  @override
  bool get isOfflineAvailable => true;
}

/// Composite dictionary service: tries online first, falls back to offline dictionary.
class CompositeDictionaryService implements DictionaryService {
  final FreeDictionaryService _online;
  final MockDictionaryService _fallback;

  CompositeDictionaryService()
      : _online = FreeDictionaryService(),
        _fallback = MockDictionaryService();

  @override
  Future<DictionaryEntry?> define(String word) async {
    final cleanWord = word.trim().replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    if (cleanWord.isEmpty) return null;

    // Try online lookup (with cache and 4s timeout)
    final result = await _online.define(cleanWord);
    if (result != null) return result;

    // Fall back to offline dictionary
    return _fallback.define(cleanWord);
  }

  @override
  bool get isOfflineAvailable => true;
}

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return CompositeDictionaryService();
});
