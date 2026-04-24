import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../core/services/secure_storage_service.dart';

enum SortType { name, time }
enum SortOrder { ascending, descending }

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
  SortType _sortType = SortType.name;
  SortOrder _sortOrder = SortOrder.ascending;

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
  SortType get sortType => _sortType;
  SortOrder get sortOrder => _sortOrder;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _isLiveEditMode = prefs.getBool('isLiveEditMode') ?? true;
    _githubToken = await SecureStorageService.getGithubToken();
    _githubUsername = prefs.getString('githubUsername');
    _githubAvatarUrl = prefs.getString('githubAvatarUrl');
    _selectedRepoFullName = prefs.getString('selectedRepoFullName');
    _githubClientId = prefs.getString('githubClientId') ?? AppConfig.githubClientId;
    _pushOnSave = prefs.getBool('pushOnSave') ?? true;
    _pushOnCreate = prefs.getBool('pushOnCreate') ?? true;
    _pushOnDelete = prefs.getBool('pushOnDelete') ?? false;
    _autoPull = prefs.getBool('autoPull') ?? true;
    _autoPullInterval = prefs.getInt('autoPullInterval') ?? 15;
    
    final sortTypeStr = prefs.getString('sortType') ?? 'name';
    _sortType = sortTypeStr == 'time' ? SortType.time : SortType.name;
    
    final sortOrderStr = prefs.getString('sortOrder') ?? 'ascending';
    _sortOrder = sortOrderStr == 'descending' ? SortOrder.descending : SortOrder.ascending;
    
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

  Future<void> setSortType(SortType type) async {
    _sortType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sortType', type == SortType.name ? 'name' : 'time');
    notifyListeners();
  }

  Future<void> setSortOrder(SortOrder order) async {
    _sortOrder = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sortOrder', order == SortOrder.ascending ? 'ascending' : 'descending');
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
    await SecureStorageService.saveGithubToken(token);
    final prefs = await SharedPreferences.getInstance();
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
    await SecureStorageService.deleteGithubToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('githubUsername');
    await prefs.remove('githubAvatarUrl');
    await prefs.remove('selectedRepoFullName');
    notifyListeners();
  }
}
