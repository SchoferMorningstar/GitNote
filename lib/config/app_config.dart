import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get githubClientId => dotenv.env['GITHUB_CLIENT_ID'] ?? '';
  static String get tipUrl => dotenv.env['TIP_URL'] ?? '';
}
