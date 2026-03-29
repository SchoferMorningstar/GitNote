import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool _isLiveEditMode = true;
  String? _githubToken;
  String? _githubUsername;
  String? _githubAvatarUrl;
  String? _selectedRepoFullName;
  String? _githubClientId = AppConfig.githubClientId;
  bool _pushOnSave = true;
  bool _pushOnCreate = true;
  bool _pushOnDelete = false;
  bool _autoPull = true;
  int _autoPullInterval = 15;

  bool get isDarkMode => _isDarkMode;
  bool get isLiveEditMode => _isLiveEditMode;
  String? get githubToken => _githubToken;
  String? get githubUsername => _githubUsername;
  String? get githubAvatarUrl => _githubAvatarUrl;
  String? get selectedRepoFullName => _selectedRepoFullName;
  String? get githubClientId => _githubClientId;
  bool get isGitHubConnected => _githubToken != null;
  bool get pushOnSave => _pushOnSave;
  bool get pushOnCreate => _pushOnCreate;
  bool get pushOnDelete => _pushOnDelete;
  bool get autoPull => _autoPull;
  int get autoPullInterval => _autoPullInterval;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _isLiveEditMode = prefs.getBool('isLiveEditMode') ?? false;
    _githubToken = prefs.getString('githubToken');
    _githubUsername = prefs.getString('githubUsername');
    _githubAvatarUrl = prefs.getString('githubAvatarUrl');
    _selectedRepoFullName = prefs.getString('selectedRepoFullName');
    _githubClientId = prefs.getString('githubClientId') ?? AppConfig.githubClientId;
    _pushOnSave = prefs.getBool('pushOnSave') ?? true;
    _pushOnCreate = prefs.getBool('pushOnCreate') ?? true;
    _pushOnDelete = prefs.getBool('pushOnDelete') ?? false;
    _autoPull = prefs.getBool('autoPull') ?? true;
    _autoPullInterval = prefs.getInt('autoPullInterval') ?? 15;
    notifyListeners();
  }

  Future<void> setGithubClientId(String id) async {
    _githubClientId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('githubClientId', id);
    notifyListeners();
  }

  Future<void> togglePushOnSave(bool value) async {
    _pushOnSave = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushOnSave', value);
    notifyListeners();
  }

  Future<void> togglePushOnCreate(bool value) async {
    _pushOnCreate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushOnCreate', value);
    notifyListeners();
  }

  Future<void> togglePushOnDelete(bool value) async {
    _pushOnDelete = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushOnDelete', value);
    notifyListeners();
  }

  Future<void> toggleAutoPull(bool value) async {
    _autoPull = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoPull', value);
    notifyListeners();
  }

  Future<void> setAutoPullInterval(int minutes) async {
    if (minutes < 15) minutes = 15;
    _autoPullInterval = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoPullInterval', minutes);
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }

  Future<void> toggleLiveEdit(bool isLive) async {
    _isLiveEditMode = isLive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLiveEditMode', isLive);
    notifyListeners();
  }

  Future<void> setGitHubAuth(String token, String username, String avatarUrl) async {
    _githubToken = token;
    _githubUsername = username;
    _githubAvatarUrl = avatarUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('githubToken', token);
    await prefs.setString('githubUsername', username);
    await prefs.setString('githubAvatarUrl', avatarUrl);
    notifyListeners();
  }

  Future<void> setSelectedRepo(String? repoFullName) async {
    _selectedRepoFullName = repoFullName;
    final prefs = await SharedPreferences.getInstance();
    if (repoFullName == null) {
      await prefs.remove('selectedRepoFullName');
    } else {
      await prefs.setString('selectedRepoFullName', repoFullName);
    }
    notifyListeners();
  }

  Future<void> clearGitHubAuth() async {
    _githubToken = null;
    _githubUsername = null;
    _githubAvatarUrl = null;
    _selectedRepoFullName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('githubToken');
    await prefs.remove('githubUsername');
    await prefs.remove('githubAvatarUrl');
    await prefs.remove('selectedRepoFullName');
    notifyListeners();
  }
}
