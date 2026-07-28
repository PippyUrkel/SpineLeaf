import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

/// Abstract dictionary service interface
abstract class DictionaryService {
  Future<DictionaryEntry?> define(String word);
  bool get isOfflineAvailable;
}

/// Mock dictionary with common English words
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
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Clearly expressing or indicating something.',
          example: 'The ruined building was eloquent of the horrors of war.',
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
    'paradox': const DictionaryEntry(
      word: 'paradox',
      pronunciation: '/ˈpær.ə.dɒks/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A seemingly absurd or contradictory statement or proposition which when investigated may prove to be well founded or true.',
          example: 'The paradox of standing on one\'s head to see the world more clearly.',
        ),
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A person or thing that combines contradictory features or qualities.',
          example: 'He was a paradox—a loner who loved to party.',
        ),
      ],
    ),
    'resilience': const DictionaryEntry(
      word: 'resilience',
      pronunciation: '/rɪˈzɪl.i.əns/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'The capacity to withstand or to recover quickly from difficulties; toughness.',
          example: 'The resilience of the human spirit is remarkable.',
        ),
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'The ability of a substance or object to spring back into shape; elasticity.',
          example: 'The resilience of rubber allows it to return to its original form.',
        ),
      ],
    ),
    'algorithm': const DictionaryEntry(
      word: 'algorithm',
      pronunciation: '/ˈæl.ɡə.rɪð.əm/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A process or set of rules to be followed in calculations or other problem-solving operations.',
          example: 'The search engine uses a complex algorithm to rank results.',
        ),
      ],
    ),
    'melancholy': const DictionaryEntry(
      word: 'melancholy',
      pronunciation: '/ˈmel.ən.kɒl.i/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun',
          definition: 'A deep, pensive, and long-lasting sadness.',
          example: 'A sense of melancholy hung over the old house.',
        ),
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Having a feeling of melancholy; sad and pensive.',
          example: 'His melancholy eyes told a story of loss.',
        ),
      ],
    ),
    'ubiquitous': const DictionaryEntry(
      word: 'ubiquitous',
      pronunciation: '/juːˈbɪk.wɪ.təs/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Present, appearing, or found everywhere.',
          example: 'Smartphones have become ubiquitous in modern society.',
        ),
      ],
    ),
    'the': const DictionaryEntry(
      word: 'the',
      pronunciation: '/ðə, ðiː/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'determiner',
          definition: 'Denoting one or more people or things already mentioned or assumed to be common knowledge.',
          example: 'What\'s the matter?',
        ),
      ],
    ),
    'profound': const DictionaryEntry(
      word: 'profound',
      pronunciation: '/prəˈfaʊnd/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Very great or intense.',
          example: 'Profound feelings of disquiet settled over her.',
        ),
        DictionaryDefinition(
          partOfSpeech: 'adjective',
          definition: 'Showing great knowledge or insight.',
          example: 'A profound philosophical question.',
        ),
      ],
    ),
  };

  @override
  Future<DictionaryEntry?> define(String word) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate lookup
    final lower = word.toLowerCase().trim();
    if (_dictionary.containsKey(lower)) {
      return _dictionary[lower];
    }
    // Generate a generic entry for unknown words
    return DictionaryEntry(
      word: lower,
      pronunciation: '/$lower/',
      definitions: [
        DictionaryDefinition(
          partOfSpeech: 'noun/verb/adjective',
          definition: 'Definition not available in the offline dictionary. Connect to the internet for a complete definition.',
          example: 'Try looking up "$lower" in an online dictionary for more details.',
        ),
      ],
    );
  }

  @override
  bool get isOfflineAvailable => true;
}

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return MockDictionaryService();
});
