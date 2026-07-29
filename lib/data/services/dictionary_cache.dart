import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Caches dictionary lookups in SharedPreferences for offline access
/// and reduced API usage.
class DictionaryCache {
  static const _prefix = 'dict_cache_';

  /// Look up a cached entry.
  Future<DictionaryEntry?> get(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefix + word.toLowerCase().trim();
    final json = prefs.getString(key);
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return _entryFromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Cache a dictionary entry.
  Future<void> put(String word, DictionaryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefix + word.toLowerCase().trim();
    final json = jsonEncode(_entryToJson(entry));
    await prefs.setString(key, json);
  }

  /// Check if a word is cached.
  Future<bool> has(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefix + word.toLowerCase().trim();
    return prefs.containsKey(key);
  }

  Map<String, dynamic> _entryToJson(DictionaryEntry entry) => {
    'word': entry.word,
    'pronunciation': entry.pronunciation,
    'phoneticAudioUrl': entry.phoneticAudioUrl,
    'definitions': entry.definitions.map((d) => {
      'partOfSpeech': d.partOfSpeech,
      'definition': d.definition,
      'example': d.example,
      'synonyms': d.synonyms,
      'antonyms': d.antonyms,
    }).toList(),
  };

  DictionaryEntry _entryFromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String? ?? '',
      pronunciation: json['pronunciation'] as String?,
      phoneticAudioUrl: json['phoneticAudioUrl'] as String?,
      definitions: (json['definitions'] as List<dynamic>?)?.map((d) {
        final map = d as Map<String, dynamic>;
        return DictionaryDefinition(
          partOfSpeech: map['partOfSpeech'] as String? ?? '',
          definition: map['definition'] as String? ?? '',
          example: map['example'] as String?,
          synonyms: (map['synonyms'] as List<dynamic>?)?.cast<String>() ?? const [],
          antonyms: (map['antonyms'] as List<dynamic>?)?.cast<String>() ?? const [],
        );
      }).toList() ?? const [],
    );
  }
}
