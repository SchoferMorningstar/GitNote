import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/github_provider.dart';
import 'providers/note_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

import 'core/services/github_api_service.dart';
import 'core/services/local_file_service.dart';
import 'core/services/sync_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final localFileService = LocalFileService();
  final githubApiService = GitHubApiService();
  final syncManager = SyncManager(githubApiService, localFileService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider(localFileService)),
        ChangeNotifierProvider(create: (_) => GitHubProvider(githubApiService, syncManager)),
      ],
      child: const GitNoteApp(),
    ),
  );
}

class GitNoteApp extends StatelessWidget {
  const GitNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'GitNote',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: const Color(0xFF3F51B5),
          secondary: const Color(0xFF00C853), // Emerald
          surface: const Color(0xFFF8F9FA),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          primary: const Color(0xFF7986CB),
          secondary: const Color(0xFF69F0AE),
          surface: const Color(0xFF121212),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      themeMode: settings.themeMode,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
