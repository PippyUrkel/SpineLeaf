import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/repositories/repositories.dart';

class RsvpScreen extends ConsumerStatefulWidget {
  final String bookId;
  final int chapterIndex;
  final int wordIndex;

  const RsvpScreen({
    super.key,
    required this.bookId,
    this.chapterIndex = 0,
    this.wordIndex = 0,
  });

  @override
  ConsumerState<RsvpScreen> createState() => _RsvpScreenState();
}

class _RsvpScreenState extends ConsumerState<RsvpScreen> {
  List<String> _words = [];
  int _currentWordIndex = 0;
  int _wpm = kDefaultWpm;
  bool _isPlaying = false;
  Timer? _timer;
  String _chapterTitle = '';
  int _totalChapters = 0;

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  void _loadChapter() {
    final repo = ref.read(bookRepositoryProvider);
    final chapters = repo.getChapters(widget.bookId);
    _totalChapters = chapters.length;

    if (widget.chapterIndex < chapters.length) {
      final chapter = chapters[widget.chapterIndex];
      _chapterTitle = chapter.title;
      _words = chapter.content
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      _currentWordIndex = widget.wordIndex.clamp(0, _words.length - 1);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    final interval = Duration(milliseconds: (60000 / _wpm).round());
    _timer = Timer.periodic(interval, (timer) {
      if (_currentWordIndex < _words.length - 1) {
        setState(() {
          _currentWordIndex++;
        });
      } else {
        setState(() {
          _isPlaying = false;
          _timer?.cancel();
        });
      }
    });
  }

  void _adjustWpm(int delta) {
    setState(() {
      _wpm = (_wpm + delta).clamp(kMinWpm, kMaxWpm);
      if (_isPlaying) {
        _startTimer(); // Restart with new speed
      }
    });
  }

  void _jumpWords(int delta) {
    setState(() {
      _currentWordIndex = (_currentWordIndex + delta).clamp(0, _words.length - 1);
    });
  }

  void _setPresetWpm(int wpm) {
    setState(() {
      _wpm = wpm;
      if (_isPlaying) {
        _startTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentWord = _words.isNotEmpty ? _words[_currentWordIndex] : '';
    final progress = _words.isNotEmpty ? _currentWordIndex / _words.length : 0.0;

    // Find the ORP (Optimal Recognition Point) - roughly 1/3 of the way through
    int orpIndex = 0;
    if (currentWord.isNotEmpty) {
      orpIndex = (currentWord.length * 0.35).floor().clamp(0, currentWord.length - 1);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Column(
          children: [
            Text(
              _chapterTitle,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            Text(
              'Chapter ${widget.chapterIndex + 1} of $_totalChapters',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white10,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Word position
            Text(
              '${_currentWordIndex + 1} / ${_words.length}',
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 12,
              ),
            ),

            // Main word display
            Expanded(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Focus line
                        Container(
                          width: 280,
                          height: 1,
                          color: Colors.white10,
                        ),
                        const SizedBox(height: 20),
                        // Word with ORP highlight
                        SizedBox(
                          height: 80,
                          child: currentWord.isNotEmpty
                              ? RichText(
                                  text: TextSpan(
                                    children: [
                                      // Before ORP
                                      TextSpan(
                                        text: currentWord.substring(0, orpIndex),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w300,
                                          color: Colors.white70,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      // ORP character
                                      TextSpan(
                                        text: currentWord[orpIndex],
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.primary,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      // After ORP
                                      if (orpIndex < currentWord.length - 1)
                                        TextSpan(
                                          text: currentWord.substring(orpIndex + 1),
                                          style: const TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.w300,
                                            color: Colors.white70,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : const SizedBox(),
                        ),
                        const SizedBox(height: 20),
                        // Focus line
                        Container(
                          width: 280,
                          height: 1,
                          color: Colors.white10,
                        ),
                        const SizedBox(height: 24),
                        // Play status
                        AnimatedOpacity(
                          opacity: _isPlaying ? 0 : 0.5,
                          duration: kFastAnimation,
                          child: const Text(
                            'Tap to start',
                            style: TextStyle(color: Colors.white38, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // WPM display & presets
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // WPM presets
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: kWpmPresets.map((preset) {
                      final isSelected = _wpm == preset;
                      return ChoiceChip(
                        label: Text('$preset'),
                        selected: isSelected,
                        onSelected: (_) => _setPresetWpm(preset),
                        labelStyle: TextStyle(
                          color: isSelected ? null : Colors.white70,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white10,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // WPM slider
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white54),
                        onPressed: () => _adjustWpm(-25),
                      ),
                      Expanded(
                        child: Slider(
                          value: _wpm.toDouble(),
                          min: kMinWpm.toDouble(),
                          max: kMaxWpm.toDouble(),
                          onChanged: (v) {
                            _setPresetWpm(v.round());
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white54),
                        onPressed: () => _adjustWpm(25),
                      ),
                    ],
                  ),
                  Text(
                    '$_wpm WPM',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Jump back 10
                  IconButton.filledTonal(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => _jumpWords(-10),
                    tooltip: 'Back 10 words',
                  ),
                  // Previous word
                  IconButton.filledTonal(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () => _jumpWords(-1),
                    tooltip: 'Previous word',
                  ),
                  // Play/Pause
                  FloatingActionButton(
                    onPressed: _togglePlayPause,
                    child: AnimatedSwitcher(
                      duration: kFastAnimation,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        key: ValueKey(_isPlaying),
                        size: 32,
                      ),
                    ),
                  ),
                  // Next word
                  IconButton.filledTonal(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => _jumpWords(1),
                    tooltip: 'Next word',
                  ),
                  // Jump forward 10
                  IconButton.filledTonal(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () => _jumpWords(10),
                    tooltip: 'Forward 10 words',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
