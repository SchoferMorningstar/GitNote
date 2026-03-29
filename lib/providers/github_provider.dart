import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:github/github.dart' as gh;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../utils/merge_helper.dart';
import 'note_provider.dart';
import 'settings_provider.dart';

class GitHubProvider with ChangeNotifier {
  gh.GitHub? _client;
  bool _isSyncing = false;
  bool _isConnecting = false;
  Timer? _syncTimer;

  bool get isSyncing => _isSyncing;
  bool get isConnecting => _isConnecting;

  // --- Initialization ---

  void _initClient(String token) {
    _client = gh.GitHub(auth: gh.Authentication.withToken(token));
  }

  // --- Authentication (OAuth Device Flow) ---

  Future<Map<String, dynamic>?> requestDeviceCode(String clientId) async {
    _isConnecting = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('https://github.com/login/device/code'),
        headers: {'Accept': 'application/json'},
        body: {'client_id': clientId, 'scope': 'repo user'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error requesting device code: $e');
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
    return null;
  }

  Future<String?> pollForToken(String clientId, String deviceCode, int interval) async {
    final poller = Uri.parse('https://github.com/login/oauth/access_token');
    
    for (int i = 0; i < 20; i++) {
      await Future.delayed(Duration(seconds: interval));
      try {
        final resp = await http.post(
          poller,
          headers: {'Accept': 'application/json'},
          body: {
            'client_id': clientId,
            'device_code': deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
        );
        final data = jsonDecode(resp.body);
        if (data['access_token'] != null) {
          _isConnecting = false;
          _initClient(data['access_token']);
          notifyListeners();
          return data['access_token'];
        }
        if (data['error'] == 'authorization_pending') continue;
        if (data['error'] == 'expired_token' || data['error'] == 'access_denied') break;
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    }
    _isConnecting = false;
    notifyListeners();
    return null;
  }

  Future<gh.User?> verifyToken(String token) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final user = await client.users.getCurrentUser();
      _client = client;
      return user;
    } catch (e) {
      debugPrint('GitHub Token Verification Failed: $e');
      return null;
    }
  }

  // --- Repository & Commit Management ---

  Future<List<gh.Repository>> fetchRepositories(String token) async {
    _initClient(token);
    try {
      return await _client!.repositories.listRepositories().toList();
    } catch (e) {
      debugPrint('Failed to fetch repositories: $e');
      return [];
    }
  }

  Future<List<gh.RepositoryCommit>> fetchCommits(String repoFullName) async {
    if (_client == null) return [];
    try {
      final slug = gh.RepositorySlug.full(repoFullName);
      return await _client!.repositories.listCommits(slug).take(20).toList();
    } catch (e) {
      debugPrint('Failed to fetch commits: $e');
      return [];
    }
  }

  // --- Auto-Sync Control ---

  void stopAutoPull() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void startAutoPull(SettingsProvider settings, NoteProvider noteProvider) {
    stopAutoPull();
    if (!settings.autoPull || !settings.isGitHubConnected || settings.selectedRepoFullName == null) return;

    _syncTimer = Timer.periodic(Duration(minutes: settings.autoPullInterval), (timer) {
      if (settings.autoPull) {
        pullLatestNotes(
          token: settings.githubToken!,
          repoFullName: settings.selectedRepoFullName!,
          noteProvider: noteProvider,
        );
      }
    });

    pullLatestNotes(
      token: settings.githubToken!,
      repoFullName: settings.selectedRepoFullName!,
      noteProvider: noteProvider,
    );
  }

  // --- Core Sync Operations ---

  Future<void> pullLatestNotes({
    required String token,
    required String repoFullName,
    required NoteProvider noteProvider,
  }) async {
    if (_isSyncing) return;
    _initClient(token);
    _isSyncing = true;
    notifyListeners();

    try {
      final slug = gh.RepositorySlug.full(repoFullName);
      final tree = await _client!.git.getTree(slug, 'main', recursive: true);
      
      if (tree.entries != null) {
        for (final item in tree.entries!) {
          if (item.type == 'blob' && item.path!.endsWith('.md')) {
            await _syncFileLocally(slug, item.path!, noteProvider);
          }
        }
        await noteProvider.refresh();
      }
    } catch (e) {
      debugPrint('Auto-Pull Failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncFileLocally(gh.RepositorySlug slug, String remotePath, NoteProvider noteProvider) async {
    try {
      final contentResp = await _client!.repositories.getContents(slug, remotePath);
      if (contentResp.file != null && contentResp.file!.content != null) {
        final remoteContent = utf8.decode(base64Decode(contentResp.file!.content!.replaceAll('\n', '')));
        final localFile = File(p.join(noteProvider.rootPath, remotePath));
        
        if (!await localFile.parent.exists()) await localFile.parent.create(recursive: true);

        String finalContent = remoteContent;
        if (await localFile.exists()) {
          final localContent = await localFile.readAsString();
          finalContent = MergeHelper.merge(localContent, remoteContent);
        }
        await localFile.writeAsString(finalContent);
      }
    } catch (_) {}
  }

  Future<void> syncNote({
    required String token,
    required String repoFullName,
    required String filename,
    required String content,
  }) async {
    _initClient(token);
    _isSyncing = true;
    notifyListeners();

    try {
      final slug = gh.RepositorySlug.full(repoFullName);
      String? sha;
      try {
        final existing = await _client?.repositories.getContents(slug, filename);
        if (existing?.file != null) sha = existing!.file!.sha;
      } catch (_) {}

      final encodedContent = base64Encode(utf8.encode(content));
      if (sha != null) {
        await _client?.repositories.updateFile(slug, filename, 'Update $filename via GitNote', encodedContent, sha);
      } else {
        await _client?.repositories.createFile(slug, gh.CreateFile(path: filename, message: 'Create $filename via GitNote', content: encodedContent));
      }
    } catch (e) {
      debugPrint('Failed to sync note to GitHub: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> deleteNote({
    required String token,
    required String repoFullName,
    required String filename,
  }) async {
    _initClient(token);
    try {
      final slug = gh.RepositorySlug.full(repoFullName);
      final content = await _client?.repositories.getContents(slug, filename);
      if (content?.file != null && content!.file!.sha != null) {
        await _client?.repositories.deleteFile(slug, filename, 'Delete $filename via GitNote', content.file!.sha!, 'main');
      }
    } catch (e) {
      debugPrint('Failed to delete note from GitHub: $e');
    }
  }

  Future<void> deleteDirectory({
    required String token,
    required String repoFullName,
    required String directoryPath,
  }) async {
    _initClient(token);
    _isSyncing = true;
    notifyListeners();

    try {
      final slug = gh.RepositorySlug.full(repoFullName);
      final tree = await _client!.git.getTree(slug, 'main', recursive: true);
      
      if (tree.entries != null) {
        final normalizedDir = directoryPath.endsWith('/') ? directoryPath : '$directoryPath/';
        for (final item in tree.entries!) {
          if (item.type == 'blob' && item.path!.startsWith(normalizedDir)) {
            try {
              final content = await _client!.repositories.getContents(slug, item.path!);
              await _client!.repositories.deleteFile(slug, item.path!, 'Delete ${item.path} via GitNote', content.file!.sha!, 'main');
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to delete directory: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- Recovery Logic ---

  Future<void> restoreFromCommit({
    required String token,
    required String repoFullName,
    required String sha,
    required NoteProvider noteProvider,
  }) async {
    _initClient(token);
    _isSyncing = true;
    notifyListeners();

    try {
      final slug = gh.RepositorySlug.full(repoFullName);
      final tree = await _client!.git.getTree(slug, sha, recursive: true);

      if (tree.entries != null) {
        // Hard reset local state
        final rootDir = Directory(noteProvider.rootPath);
        if (await rootDir.exists()) {
          await rootDir.listSync().forEach((e) => e.deleteSync(recursive: true));
        }

        for (final item in tree.entries!) {
          if (item.type == 'blob' && (item.path!.endsWith('.md') || item.path!.endsWith('.gitkeep'))) {
            await _syncFileLocally(slug, item.path!, noteProvider);
          }
        }
        await noteProvider.refresh();
      }
    } catch (e) {
      debugPrint('Recovery Failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
