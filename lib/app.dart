import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/repositories.dart';
import 'data/services/demo_data_service.dart';
import 'ui/navigation/app_shell.dart';
import 'ui/reader/reader_screen.dart';
import 'ui/book_details/book_details_screen.dart';
import 'ui/rsvp/rsvp_screen.dart';

// App-level providers
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final seedColorProvider = StateProvider<Color>((ref) => const Color(0xFF6750A4));
final appInitializedProvider = StateProvider<bool>((ref) => false);

class SpineLeafApp extends ConsumerStatefulWidget {
  const SpineLeafApp({super.key});

  @override
  ConsumerState<SpineLeafApp> createState() => _SpineLeafAppState();
}

class _SpineLeafAppState extends ConsumerState<SpineLeafApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final repo = ref.read(bookRepositoryProvider);
    final prefsRepo = ref.read(preferencesRepositoryProvider);

    await prefsRepo.load();
    if (!prefsRepo.hasSeededWelcomeBooklet) {
      DemoDataService.seedWelcomeBooklet(repo);
      await prefsRepo.saveWelcomeBookletSeeded(true);
    }

    ref.read(themeModeProvider.notifier).state = prefsRepo.themeMode;
    ref.read(seedColorProvider.notifier).state = prefsRepo.seedColor;
    ref.read(appInitializedProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);
    final initialized = ref.watch(appInitializedProvider);

    if (!initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SpineLeaf',
      themeMode: themeMode,
      theme: AppTheme.light(seedColor: seedColor),
      darkTheme: AppTheme.dark(seedColor: seedColor),
      home: const AppShell(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/reader':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ReaderScreen(
                bookId: args['bookId'] as String,
                startChapter: args['startChapter'] as int? ?? 0,
                startPage: args['startPage'] as int? ?? 0,
              ),
            );
          case '/book-details':
            final bookId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => BookDetailsScreen(bookId: bookId),
            );
          case '/rsvp':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => RsvpScreen(
                bookId: args['bookId'] as String,
                chapterIndex: args['chapterIndex'] as int? ?? 0,
                wordIndex: args['wordIndex'] as int? ?? 0,
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const AppShell(),
            );
        }
      },
    );
  }
}
