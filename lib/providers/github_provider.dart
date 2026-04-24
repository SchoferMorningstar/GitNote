import 'package:flutter/material.dart';
import 'package:github/github.dart' as gh;
import '../core/services/github_api_service.dart';
import '../core/services/sync_manager.dart';
import 'settings_provider.dart';

class GitHubProvider with ChangeNotifier {
  final GitHubApiService _apiService;
  final SyncManager _syncManager;

  bool _isConnecting = false;

  GitHubProvider(this._apiService, this._syncManager);

  bool get isConnecting => _isConnecting;
  bool get isSyncing => _syncManager.isSyncing;

  Future<Map<String, dynamic>?> requestDeviceCode(String clientId) async {
    _isConnecting = true;
    notifyListeners();
    final result = await _apiService.requestDeviceCode(clientId);
    _isConnecting = false;
    notifyListeners();
    return result;
  }

  Future<String?> pollForToken(String clientId, String deviceCode, int interval) async {
    _isConnecting = true;
    notifyListeners();
    final token = await _apiService.pollForToken(clientId, deviceCode, interval);
    _isConnecting = false;
    notifyListeners();
    return token;
  }

  Future<gh.User?> verifyToken(String token) async {
    return await _apiService.verifyToken(token);
  }

  Future<List<gh.Repository>> fetchRepositories(String token) async {
    return await _apiService.fetchRepositories(token);
  }

  Future<List<gh.RepositoryCommit>> fetchCommits(String token, String repoFullName) async {
    return await _apiService.fetchCommits(token, repoFullName);
  }

  Future<gh.GitTree?> getTree(String token, String repoFullName, String sha) async {
    return await _apiService.getTree(token, repoFullName, sha);
  }

  void startAutoPull(SettingsProvider settings, VoidCallback onSyncComplete) {
    _syncManager.startAutoPull(settings, () {
      notifyListeners();
      onSyncComplete();
    });
  }

  void stopAutoPull() {
    _syncManager.stopAutoPull();
  }

  Future<void> pullLatestNotes({required String token, required String repoFullName, required VoidCallback onSyncComplete}) async {
    notifyListeners();
    await _syncManager.pullLatestNotes(token: token, repoFullName: repoFullName);
    notifyListeners();
    onSyncComplete();
  }

  Future<void> syncNote({required String token, required String repoFullName, required String filename, required String content}) async {
    notifyListeners();
    await _apiService.syncNote(token: token, repoFullName: repoFullName, filename: filename, content: content);
    notifyListeners();
  }

  Future<void> deleteNote({required String token, required String repoFullName, required String filename}) async {
    await _apiService.deleteNote(token: token, repoFullName: repoFullName, filename: filename);
  }

  Future<void> deleteDirectory({required String token, required String repoFullName, required String directoryPath}) async {
    notifyListeners();
    await _apiService.deleteDirectory(token: token, repoFullName: repoFullName, directoryPath: directoryPath);
    notifyListeners();
  }

  Future<void> recoverItem({
    required String token,
    required String repoFullName,
    required String commitSha,
    required String path,
    required bool isFolder,
    required VoidCallback onSyncComplete,
  }) async {
    notifyListeners();
    await _syncManager.recoverSpecificItem(
      token: token,
      repoFullName: repoFullName,
      commitSha: commitSha,
      path: path,
      isFolder: isFolder,
    );
    notifyListeners();
    onSyncComplete();
  }
}
