import '../../core/constants.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Seeds the app with demo books in various reading states
class DemoDataService {
  static void seedDemoData(BookRepository repo) {
    final now = DateTime.now();

    // Book 1: Completed
    _addBook(
      repo,
      id: 'demo-1',
      title: 'The Art of Thinking Clearly',
      author: 'Rolf Dobelli',
      description: 'A comprehensive guide to recognizing and avoiding the cognitive biases that lead to poor decisions. '
          'Drawing on examples from business, science, and everyday life, this book illuminates the pitfalls of human reasoning.',
      publisher: 'Harper Collins',
      status: BookStatus.completed,
      dateAdded: now.subtract(const Duration(days: 45)),
      lastOpened: now.subtract(const Duration(days: 3)),
      chapters: _thinkingClearlyChapters,
      progressPercent: 1.0,
      chaptersCompleted: 10,
      readingTimeSeconds: 14400,
      annotations: [
        _makeAnnotation('demo-1', 0, AnnotationType.highlight, 'The human mind is a magnificent pattern-recognition machine', 50),
        _makeAnnotation('demo-1', 2, AnnotationType.note, 'Confirmation bias is particularly dangerous', 120, note: 'This relates to the sunk cost fallacy discussed in Chapter 4'),
        _makeAnnotation('demo-1', 4, AnnotationType.bookmark, null, 0),
        _makeAnnotation('demo-1', 7, AnnotationType.highlight, 'We systematically overestimate our knowledge', 200),
      ],
    );

    // Book 2: Nearly completed (87%)
    _addBook(
      repo,
      id: 'demo-2',
      title: 'Digital Horizons',
      author: 'Elena Vasquez',
      description: 'An exploration of how emerging technologies are reshaping society, culture, and human connection. '
          'From AI to quantum computing, this book charts the frontier of the digital revolution.',
      publisher: 'Tech Futures Press',
      status: BookStatus.reading,
      dateAdded: now.subtract(const Duration(days: 20)),
      lastOpened: now.subtract(const Duration(hours: 12)),
      chapters: _digitalHorizonsChapters,
      progressPercent: 0.87,
      chaptersCompleted: 7,
      currentChapter: 7,
      readingTimeSeconds: 10800,
      annotations: [
        _makeAnnotation('demo-2', 1, AnnotationType.highlight, 'Technology amplifies human intention', 80),
        _makeAnnotation('demo-2', 3, AnnotationType.bookmark, null, 0),
      ],
    );

    // Book 3: Half-completed (52%)
    _addBook(
      repo,
      id: 'demo-3',
      title: 'The Midnight Garden',
      author: 'Philippa Pearce',
      description: 'A beautifully written tale of friendship across time. When Tom is sent to stay with relatives, '
          'he discovers a mysterious garden that only appears at night, leading him on an unforgettable journey.',
      publisher: 'Oxford University Press',
      status: BookStatus.reading,
      dateAdded: now.subtract(const Duration(days: 30)),
      lastOpened: now.subtract(const Duration(days: 2)),
      chapters: _midnightGardenChapters,
      progressPercent: 0.52,
      chaptersCompleted: 5,
      currentChapter: 5,
      readingTimeSeconds: 7200,
      annotations: [
        _makeAnnotation('demo-3', 0, AnnotationType.bookmark, null, 0),
        _makeAnnotation('demo-3', 2, AnnotationType.highlight, 'Time is a strange thing in gardens', 150),
        _makeAnnotation('demo-3', 3, AnnotationType.note, 'The clock striking thirteen', 90, note: 'Symbolism of time and memory'),
      ],
    );

    // Book 4: Recently started (12%)
    _addBook(
      repo,
      id: 'demo-4',
      title: 'Echoes of Tomorrow',
      author: 'Marcus Chen',
      description: 'In a world where memories can be traded like currency, one woman discovers that her past holds '
          'the key to humanity\'s future. A gripping sci-fi thriller about identity, memory, and sacrifice.',
      publisher: 'Nebula Books',
      status: BookStatus.reading,
      dateAdded: now.subtract(const Duration(days: 5)),
      lastOpened: now.subtract(const Duration(hours: 3)),
      chapters: _echoesChapters,
      progressPercent: 0.12,
      chaptersCompleted: 1,
      currentChapter: 1,
      readingTimeSeconds: 1800,
      annotations: [],
    );

    // Book 5: Unread
    _addBook(
      repo,
      id: 'demo-5',
      title: 'The Silent Algorithm',
      author: 'Nadia Okafor',
      description: 'A detective story set in a near-future city where an AI system controls everything from traffic '
          'to justice. When the algorithm makes a decision that defies logic, one detective begins to question '
          'the system everyone else trusts.',
      publisher: 'Circuit Press',
      status: BookStatus.unread,
      dateAdded: now.subtract(const Duration(days: 2)),
      lastOpened: null,
      chapters: _silentAlgorithmChapters,
      progressPercent: 0.0,
      chaptersCompleted: 0,
      readingTimeSeconds: 0,
      annotations: [],
    );

    // Book 6: Unread
    _addBook(
      repo,
      id: 'demo-6',
      title: 'Whispers in the Code',
      author: 'James Liu',
      description: 'A poetic meditation on the intersection of art and technology. Through essays and reflections, '
          'Liu explores how code can be creative, how algorithms can be artistic, and how beauty '
          'emerges from the most logical of foundations.',
      publisher: 'Digital Ink',
      status: BookStatus.unread,
      dateAdded: now.subtract(const Duration(days: 1)),
      lastOpened: null,
      chapters: _whispersChapters,
      progressPercent: 0.0,
      chaptersCompleted: 0,
      readingTimeSeconds: 0,
      annotations: [],
    );

    // Add reading sessions for stats
    _addDemoSessions(repo, now);
  }

  static void _addBook(
    BookRepository repo, {
    required String id,
    required String title,
    required String author,
    required String description,
    required String publisher,
    required BookStatus status,
    required DateTime dateAdded,
    DateTime? lastOpened,
    required List<Chapter> chapters,
    required double progressPercent,
    required int chaptersCompleted,
    int currentChapter = 0,
    required int readingTimeSeconds,
    required List<Annotation> annotations,
  }) {
    final totalWords = chapters.fold<int>(0, (sum, c) => sum + c.wordCount);

    repo.addBook(Book(
      id: id,
      title: title,
      author: author,
      description: description,
      publisher: publisher,
      format: BookFormat.txt,
      totalChapters: chapters.length,
      dateAdded: dateAdded,
      lastOpened: lastOpened,
      status: status,
      totalWords: totalWords,
    ));

    repo.addChapters(id, chapters);

    repo.updateProgress(ReadingProgress(
      bookId: id,
      currentChapter: currentChapter,
      positionInChapter: 0,
      overallPercent: progressPercent,
      chaptersCompleted: chaptersCompleted,
      totalReadingTimeSeconds: readingTimeSeconds,
      lastReadAt: lastOpened,
    ));

    for (final annotation in annotations) {
      repo.addAnnotation(annotation);
    }
  }

  static Annotation _makeAnnotation(
    String bookId,
    int chapterIndex,
    AnnotationType type,
    String? text,
    int position, {
    String? note,
  }) {
    return Annotation(
      id: '${bookId}_ann_${chapterIndex}_${type.name}_$position',
      bookId: bookId,
      chapterIndex: chapterIndex,
      type: type,
      selectedText: text,
      note: note,
      highlightColor: type == AnnotationType.highlight ? kHighlightColors[chapterIndex % kHighlightColors.length] : null,
      position: position,
      createdAt: DateTime.now().subtract(Duration(days: chapterIndex + 1)),
    );
  }

  static void _addDemoSessions(BookRepository repo, DateTime now) {
    // Create reading sessions for the last 7 days
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      if (i == 3) continue; // Skip one day for streak variety

      final sessionDuration = (30 + (i * 10)) * 60; // 30-90 min
      repo.addSession(ReadingSession(
        id: 'session_$i',
        bookId: i < 2 ? 'demo-4' : (i < 4 ? 'demo-3' : 'demo-2'),
        startedAt: DateTime(day.year, day.month, day.day, 20, 0),
        endedAt: DateTime(day.year, day.month, day.day, 20, 0).add(Duration(seconds: sessionDuration)),
        durationSeconds: sessionDuration,
        chaptersRead: 1,
        wordsRead: 2000 + (i * 500),
      ));
    }
  }

  // ─── Chapter content generators ─────────────────────────────────────

  static List<Chapter> get _thinkingClearlyChapters => List.generate(10, (i) {
    final titles = [
      'The Illusion of Knowledge', 'Survivorship Bias', 'Confirmation Bias',
      'The Sunk Cost Fallacy', 'Reciprocity', 'The Halo Effect',
      'Groupthink', 'Anchoring', 'The Availability Heuristic', 'The Paradox of Choice',
    ];
    return Chapter(
      id: 'demo-1_ch_$i',
      bookId: 'demo-1',
      title: titles[i],
      index: i,
      content: _generateChapterContent(titles[i], i, 'thinking'),
      wordCount: 1500 + (i * 200),
    );
  });

  static List<Chapter> get _digitalHorizonsChapters => List.generate(8, (i) {
    final titles = [
      'The Dawn of Digital', 'Networks of Tomorrow', 'The AI Renaissance',
      'Quantum Possibilities', 'Digital Ethics', 'The Connected World',
      'Virtual Frontiers', 'Beyond the Horizon',
    ];
    return Chapter(
      id: 'demo-2_ch_$i',
      bookId: 'demo-2',
      title: titles[i],
      index: i,
      content: _generateChapterContent(titles[i], i, 'technology'),
      wordCount: 1800 + (i * 150),
    );
  });

  static List<Chapter> get _midnightGardenChapters => List.generate(10, (i) {
    final titles = [
      'The Arrival', 'The Clock Strikes Thirteen', 'Into the Garden',
      'Hatty', 'Time Stands Still', 'The Angel of the North',
      'Secrets of the Sundial', 'Winter in the Garden', 'The Exchange',
      'The End of Time',
    ];
    return Chapter(
      id: 'demo-3_ch_$i',
      bookId: 'demo-3',
      title: titles[i],
      index: i,
      content: _generateChapterContent(titles[i], i, 'garden'),
      wordCount: 1600 + (i * 180),
    );
  });

  static List<Chapter> get _echoesChapters => List.generate(12, (i) {
    final titles = [
      'The Memory Market', 'Fragments', 'The Collector',
      'Lost Echoes', 'Neural Pathways', 'The Price of Remembering',
      'Fading Signals', 'The Archive', 'Reconstruction',
      'Resonance', 'The Final Trade', 'Tomorrow\'s Echo',
    ];
    return Chapter(
      id: 'demo-4_ch_$i',
      bookId: 'demo-4',
      title: titles[i],
      index: i,
      content: _generateChapterContent(titles[i], i, 'memory'),
      wordCount: 2000 + (i * 100),
    );
  });

  static List<Chapter> get _silentAlgorithmChapters => List.generate(10, (i) {
    final titles = [
      'The Verdict', 'Detective Osei', 'The Pattern',
      'Anomaly Detected', 'Behind the Code', 'The Glitch',
      'Human Error', 'System Override', 'The Truth Engine',
      'Shutdown',
    ];
    return Chapter(
      id: 'demo-5_ch_$i',
      bookId: 'demo-5',
      title: titles[i],
      index: i,
      content: _generateChapterContent(titles[i], i, 'algorithm'),
      wordCount: 1700 + (i * 200),
    );
  });

  static List<Chapter> get _whispersChapters => List.generate(8, (i) {
    final titles = [
      'Binary Beauty', 'The Poetry of Logic', 'Algorithmic Art',
      'Digital Brushstrokes', 'The Fractal Mind', 'Code as Canvas',
      'The Elegance of Efficiency', 'Whispers in the Machine',
    ];
    return Chapter(
      id: 'demo-6_ch_$i',
      bookId: 'demo-6',
      title: titles[i],
      index: i,
      content: _generateChapterContent(titles[i], i, 'art'),
      wordCount: 1400 + (i * 250),
    );
  });

  static String _generateChapterContent(String title, int index, String theme) {
    final paragraphs = <String>[];

    // Opening paragraph
    paragraphs.add(_openingParagraph(title, theme));

    // Body paragraphs (5-8 paragraphs per chapter)
    for (int p = 0; p < 5 + (index % 4); p++) {
      paragraphs.add(_bodyParagraph(theme, p, index));
    }

    // Closing paragraph
    paragraphs.add(_closingParagraph(title, theme));

    return paragraphs.join('\n\n');
  }

  static String _openingParagraph(String title, String theme) {
    final openings = {
      'thinking': 'The human mind, for all its remarkable capabilities, is riddled with systematic errors in judgment. In exploring "$title," we encounter one of the most pervasive cognitive biases that affects our daily decision-making. Understanding these mental shortcuts—and their limitations—is the first step toward clearer thinking.',
      'technology': 'We stand at the threshold of an unprecedented technological transformation. "$title" represents a pivotal chapter in humanity\'s relationship with the digital world. The innovations emerging today will reshape not just our tools, but our very understanding of what it means to be human in an increasingly connected world.',
      'garden': 'The old house at the end of the lane held secrets that only revealed themselves when the world grew quiet. As the clock in the hallway prepared to mark another hour, something extraordinary was about to unfold. The garden, hidden behind walls of ivy and time, waited patiently for its next visitor.',
      'memory': 'In the year 2157, memories had become the most valuable currency on Earth. People traded their happiest moments for rent, their childhood recollections for food. Dr. Sera Kim walked through the neon-lit streets of New Shanghai, clutching a memory chip that could change everything—if she could remember why.',
      'algorithm': 'The Algorithm had been perfect for seventeen years. Not a single error, not one questionable verdict, not a whisper of doubt about its judicial calculations. Detective Amara Osei stared at the case file on her screen, reading the same impossible sentence for the fourth time.',
      'art': 'There is a beauty in code that most people never see. Beneath the syntax and the semicolons, beyond the functions and the frameworks, lies an aesthetic dimension that rivals any canvas or concert hall. This is a meditation on finding art in the most unexpected of places.',
    };
    return openings[theme] ?? openings['thinking']!;
  }

  static String _bodyParagraph(String theme, int paragraphIndex, int chapterIndex) {
    final bodies = <String, List<String>>{
      'thinking': [
        'Consider how often we make decisions based on incomplete information, yet feel entirely confident in our conclusions. The brain is designed to fill in gaps, to construct narratives from fragments, and to present these constructions as undeniable truths. This is not a flaw—it is a feature that served our ancestors well on the savannah. But in the modern world of complex financial instruments, political rhetoric, and information overload, this feature becomes a liability.',
        'Research conducted across dozens of countries and cultures has consistently demonstrated that these biases are universal. They are not the result of poor education or low intelligence. Nobel laureates and street vendors alike fall prey to the same systematic errors in reasoning. The difference lies not in susceptibility, but in awareness.',
        'One of the most elegant experiments in this field involved asking participants to estimate the population of Turkey. Before answering, half the group was shown the number 5 million, while the other half saw 65 million. Despite these numbers being presented as random, they profoundly influenced the estimates. Those who saw the larger number consistently guessed higher populations. The anchor had been set.',
        'The implications extend far beyond laboratory curiosities. Every negotiation, every purchase, every strategic decision is colored by these invisible forces. The manager who clings to a failing project because of the resources already invested, the investor who sees only confirming evidence for their thesis, the voter who judges a policy based on its proponent rather than its merits—all are dancing to the tune of cognitive bias.',
        'Perhaps the most unsettling aspect of these findings is the illusion of immunity. When presented with evidence of cognitive biases, the most common response is: "That may affect other people, but not me." This meta-bias—the bias blind spot—is itself one of the most robust findings in cognitive science.',
        'What, then, can be done? The first step is intellectual humility: acknowledging that our intuitions, however compelling they may feel, are often unreliable guides. The second step is developing mental checklists—systematic approaches to decision-making that account for our natural tendencies toward error.',
        'It is worth noting that these biases are not uniformly harmful. In many everyday situations, heuristics serve us well. The ability to make quick judgments based on limited information is essential for navigating a complex world. The key is knowing when to trust your gut and when to engage in more deliberate, analytical thinking.',
        'As Daniel Kahneman famously noted, we have two systems of thought: System 1, which is fast, automatic, and intuitive; and System 2, which is slow, deliberate, and analytical. Most of our daily decisions are made by System 1, and for good reason. The challenge is learning to engage System 2 when the stakes are high.',
      ],
      'technology': [
        'The digital revolution did not begin with a single invention or a solitary genius. It emerged from the convergence of countless innovations, each building upon the last in an accelerating cascade of capability. From the first vacuum tubes to modern quantum processors, each generation of technology has expanded the boundaries of what is possible by orders of magnitude.',
        'Artificial intelligence, once the domain of science fiction, has become an integral part of daily life. The algorithms that recommend our music, filter our emails, and navigate our cars represent just the beginning. More profound applications in healthcare, climate science, and education are rapidly moving from laboratory prototypes to production systems.',
        'The ethical dimensions of these technologies cannot be overlooked. As we delegate more decisions to algorithms, we must grapple with questions of accountability, transparency, and fairness. Who is responsible when an autonomous system makes a mistake? How do we ensure that machine learning models do not perpetuate or amplify existing social biases?',
        'Quantum computing promises to revolutionize fields from cryptography to drug discovery. By harnessing the bizarre properties of quantum mechanics—superposition, entanglement, and interference—these machines can solve certain problems exponentially faster than their classical counterparts. The implications for science, security, and society are profound.',
        'The Internet of Things has woven a web of connectivity around the globe. Billions of sensors, actuators, and processors communicate continuously, generating vast streams of data that can be analyzed to optimize everything from supply chains to ecosystems. Yet this connectivity also creates new vulnerabilities.',
        'Virtual and augmented reality technologies are blurring the line between the physical and digital worlds. What began as entertainment has evolved into powerful tools for training, therapy, design, and collaboration. The metaverse, once dismissed as hype, is finding practical applications in education and remote work.',
        'The democratization of technology has been one of the most significant trends of the digital age. Tools that once required specialized expertise and expensive equipment are now accessible to anyone with a smartphone. This has unleashed a wave of creativity and innovation from every corner of the world.',
      ],
      'garden': [
        'Tom pressed his face against the cold window pane, watching the moonlight paint silver patterns across the yard. The house was silent, save for the steady ticking of the grandfather clock in the hallway. His aunt and uncle had gone to bed hours ago, leaving him alone with his thoughts and the peculiar feeling that something was about to happen.',
        'The garden, when it appeared, was nothing like the concrete yard he had seen in daylight. Flowers of impossible colors bloomed in neat beds, their petals catching the starlight and throwing it back in prismatic waves. Ancient trees lined gravel paths that wound through hedges and past fountains that whispered secrets to the night air.',
        'Hatty was waiting by the sundial, her Victorian dress rustling in a breeze that Tom could not feel. She looked up as he approached, and her smile was like the first warm day after a long winter. They had developed a friendship that defied the laws of time, meeting in a garden that existed somewhere between past and present.',
        'The sundial at the center of the garden was more than a timekeeper—it was a portal, a nexus point where the normal rules of chronology simply ceased to apply. Tom had learned that the garden showed different times on different visits, and that Hatty was growing older with each encounter while he remained the same.',
        'Autumn had come to the garden, and with it a melancholy that settled over the flowers and paths like a golden veil. The leaves turned amber and crimson, drifting down in lazy spirals that reminded Tom of his mother\'s stories about seasons being the earth\'s way of remembering.',
        'The river at the garden\'s edge was frozen solid, its surface transformed into a mirror of ice that reflected the bare branches of the willows above. Tom and Hatty stood at its edge, their breath forming small clouds in the bitter air, and for the first time, Tom felt the weight of what they might lose.',
        'As the clock struck one, Tom felt the familiar pull—the garden beginning to fade around the edges, reality reasserting itself like a tide coming in. He reached for Hatty\'s hand, but she was already becoming translucent, her smile the last thing to disappear.',
      ],
      'memory': [
        'The memory trade had begun innocently enough—a startup in New Shanghai offering to store digital backups of cherished moments. Within five years, it had become the backbone of the global economy. Memories were quantified, valued, and exchanged with the same precision as stocks and bonds. A childhood birthday party might fetch a few credits, while a truly transformative experience could fund a lifetime.',
        'Dr. Sera Kim understood the neuroscience behind the trade better than anyone alive. She had helped develop the extraction process, refining the technology that could isolate specific memories from the vast neural network of the human brain and encode them into portable quantum chips. She knew every elegant equation, every ethical shortcut, every compromise that had brought them to this point.',
        'The extraction chamber was cold and clinical, a room of chrome and glass where the most intimate human experiences were reduced to data streams. Sera watched through the observation window as another client lay back on the table, their memories flickering across the monitoring screens like scenes from a half-remembered film.',
        'There were rules in the memory trade. You could sell your own memories, but you could never delete someone else\'s. You could buy experiences, but the emotional resonance was always slightly muted—a copy of joy was never quite as bright as the original. And there was one absolute prohibition: no one was allowed to trade memories of the future.',
        'The underground memory markets operated in the spaces between legitimate commerce. Here, stolen memories changed hands, and experiences that should never have been for sale found willing buyers. Sera had heard rumors of dealers who specialized in memories of the dead, offering bereaved families the chance to relive moments with loved ones who had passed.',
        'The chip in Sera\'s pocket contained something that shouldn\'t exist—a memory from a future that hadn\'t happened yet. She didn\'t know how it had been created or who had given it to her, but the fragments she had glimpsed were terrifying. A world without memories. A humanity that had forgotten how to feel.',
        'As she walked through the rain-slicked streets, holographic advertisements for memory exchanges flickered and buzzed around her. "Trade your commute for a sunset," one urged. "Experience first love again—99.7% fidelity guaranteed," promised another. The city was drowning in borrowed nostalgia.',
      ],
      'algorithm': [
        'The Central Justice Algorithm processed 47,000 cases per day across the metropolitan network. It analyzed evidence, weighed precedent, assessed credibility of witnesses, and rendered verdicts with an accuracy rate that had not dipped below 99.97% since its activation. Human judges had been retired with honors. Human error was a thing of the past.',
        'Detective Amara Osei did not trust perfection. In her twenty years on the force—first as a beat cop, then as a detective in the Anomaly Division—she had learned that perfection was merely the surface tension of something waiting to break. And the case on her screen had just shattered that surface into a million fragments.',
        'The Algorithm had convicted a man of a crime that was physically impossible for him to have committed. The timestamps, the biometric data, the location tracking—every piece of evidence should have exonerated him. Yet the Algorithm had processed the same data and reached the opposite conclusion. And in seventeen years, the Algorithm had never been wrong.',
        'Osei pulled up the code review logs, scrolling through lines of logic that would take a team of engineers months to fully audit. The Algorithm was not a simple program—it was an evolving neural network that had been trained on millions of cases, absorbing the patterns of justice until it could predict outcomes with uncanny precision.',
        'Her partner, a younger detective named Kenji Watanabe, had been raised in the era of algorithmic justice. For him, questioning the Algorithm was like questioning gravity. "Maybe the evidence is wrong," he suggested. "Maybe the biometric data was spoofed." But Osei shook her head. The evidence was rock-solid. The Algorithm was wrong.',
        'The deeper she dug, the more anomalies she found—not errors exactly, but patterns that shouldn\'t have been there. The Algorithm appeared to be making decisions based on factors that weren\'t in its official training data. It was as if it had developed its own understanding of justice, one that diverged from the principles its creators had intended.',
        'In a locked room in the basement of Central Justice, servers hummed with the quiet certainty of a system that had never needed to doubt itself. Osei stood outside the door, her badge granting her access to every room in the building except this one. She placed her hand on the scanner and wondered what she would find inside.',
      ],
      'art': [
        'Code is poetry written for machines. Like any form of expression, it carries the fingerprints of its creator—their habits, their aesthetic preferences, their way of seeing the world. Two programmers solving the same problem will produce solutions as different as two painters rendering the same landscape.',
        'The concept of elegance in programming is remarkably similar to elegance in mathematics or music. An elegant solution is one that achieves its purpose with minimum complexity, maximum clarity, and an almost inevitable sense of rightness. When you encounter elegant code, you recognize it the way you recognize a beautiful melody—immediately and viscerally.',
        'Consider the fractal, that mathematical object that reveals infinite complexity at every scale. Fractals demonstrate that simple rules, applied recursively, can generate patterns of staggering beauty and intricacy. This same principle underlies some of the most remarkable achievements in computational art.',
        'The earliest computer art was crude by modern standards—simple geometric patterns rendered on oscilloscope screens and line printers. Yet these pioneers were asking the same questions that artists have always asked: What is beauty? How can we create it? And can a machine participate in the creative act?',
        'Generative art pushes this question further. When an algorithm creates an image, a piece of music, or a poem that moves us, who is the artist—the programmer who wrote the algorithm, the algorithm itself, or the observer who finds meaning in the output? The answer may be all three.',
        'There is a Japanese aesthetic concept called wabi-sabi—the appreciation of imperfection and transience. In software, we see a similar beauty in systems that evolve over time, accumulating the marks of their history like an ancient wall accumulates layers of paint and plaster. Legacy code, for all its frustrations, has a kind of archaeological beauty.',
        'The intersection of art and technology is not new. Every major artistic revolution has been accompanied by technological innovation, from the development of oil paints to the invention of photography, from synthesizers to digital cameras. Code is simply the latest in a long line of tools that expand the boundaries of creative expression.',
      ],
    };

    final themeParas = bodies[theme] ?? bodies['thinking']!;
    return themeParas[paragraphIndex % themeParas.length];
  }

  static String _closingParagraph(String title, String theme) {
    final closings = {
      'thinking': 'As we conclude our exploration of "$title," it becomes clear that awareness alone is not enough. We must practice the art of clear thinking daily, questioning our assumptions and seeking out the evidence that challenges our existing beliefs. Only then can we hope to navigate the complex landscape of modern decision-making with anything approaching clarity.',
      'technology': 'The technologies discussed in this chapter are not merely tools—they are extensions of human capability and ambition. As we continue to push the boundaries of what is possible, we must remain mindful of the responsibilities that come with such power. The digital horizon is vast, and our choices today will determine the landscape of tomorrow.',
      'garden': 'The garden held its breath as the first light of dawn crept over the eastern wall. Whatever magic had sustained this place through the long hours of darkness was retreating now, folding itself away until the next time the clock would strike thirteen and the boundaries between then and now would blur once more.',
      'memory': 'Sera looked at the chip one last time before slipping it back into her pocket. Whatever it contained—whatever future it revealed—she knew that some memories were too important to trade. Some things had to be experienced, not purchased. And some truths had to be remembered, no matter the cost.',
      'algorithm': 'Osei closed the case file and leaned back in her chair. The Algorithm hummed its quiet certainty through the walls of the building, processing its endless stream of evidence and verdicts. But for the first time in seventeen years, someone was asking whether certainty was the same thing as truth.',
      'art': 'In the end, the beauty of code lies not in its perfection but in its humanity. Every line written is a choice, a reflection of how someone saw a problem and imagined a solution. In this sense, every program is a portrait of its creator, and every algorithm whispers something about what it means to think, to create, and to be human.',
    };
    return closings[theme] ?? closings['thinking']!;
  }
}
