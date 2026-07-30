import 'package:flutter/material.dart';
import '../../data/models/models.dart';

/// An improved dictionary bottom sheet that displays word definitions,
/// pronunciation, examples, synonyms, and antonyms.
class DictionarySheet extends StatelessWidget {
  final DictionaryEntry? entry;
  final bool isLoading;
  final String? errorMessage;
  final String word;

  const DictionarySheet({
    super.key,
    this.entry,
    this.isLoading = false,
    this.errorMessage,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    word,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      const SizedBox(height: 32),
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Looking up "$word"...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ] else if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (entry != null) ...[
                      // Pronunciation
                      if (entry!.pronunciation != null) ...[
                        Row(
                          children: [
                            Text(
                              entry!.pronunciation!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (entry!.phoneticAudioUrl != null)
                              IconButton(
                                icon: Icon(Icons.volume_up,
                                    size: 20, color: theme.colorScheme.primary),
                                onPressed: () {
                                  // Audio playback could be added here
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Definitions
                      ...entry!.definitions.map((def) => _buildDefinition(context, def)),

                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefinition(BuildContext context, DictionaryDefinition def) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part of speech badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              def.partOfSpeech,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Definition
          Text(def.definition, style: theme.textTheme.bodyMedium),

          // Example
          if (def.example != null) ...[
            const SizedBox(height: 4),
            Text(
              '"${def.example}"',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          // Synonyms
          if (def.synonyms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(
                  'Synonyms: ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...def.synonyms.take(5).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s, style: theme.textTheme.labelSmall),
                )),
              ],
            ),
          ],

          // Antonyms
          if (def.antonyms.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(
                  'Antonyms: ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...def.antonyms.take(5).map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(a, style: theme.textTheme.labelSmall),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
