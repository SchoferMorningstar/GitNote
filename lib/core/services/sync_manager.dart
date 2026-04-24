import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'github_api_service.dart';
import 'local_file_service.dart';
import '../../utils/merge_helper.dart';
import '../../providers/settings_provider.dart';

class SyncManager {
  final GitHubApiService _githubApi;
  final LocalFileService _localFile;
  
  bool _isSyncing = false;
  Timer? _syncTimer;

  bool get isSyncing => _isSyncing;

  SyncManager(this._githubApi, this._localFile);

  void stopAutoPull() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void startAutoPull(SettingsProvider settings, VoidCallback onSyncComplete) {
    stopAutoPull();
    if (!settings.autoPull || !settings.isGitHubConnected || settings.selectedRepoFullName == null) return;

    _syncTimer = Timer.periodic(Duration(minutes: settings.autoPullInterval), (timer) {
      if (settings.autoPull) {
        pullLatestNotes(
          token: settings.githubToken!,
          repoFullName: settings.selectedRepoFullName!,
        ).then((_) => onSyncComplete());
      }
    });

    pullLatestNotes(
      token: settings.githubToken!,
      repoFullName: settings.selectedRepoFullName!,
    ).then((_) => onSyncComplete());
  }

  Future<void> pullLatestNotes({
    required String token,
    required String repoFullName,
  }) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final tree = await _githubApi.getTree(token, repoFullName, 'main');
      if (tree != null && tree.entries != null) {
        for (final item in tree.entries!) {
          if (item.type == 'blob' && item.path!.endsWith('.md')) {
            await _syncFileLocally(token, repoFullName, item.path!);
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-Pull Failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncFileLocally(String token, String repoFullName, String remotePath) async {
    try {
      final remoteContent = await _githubApi.getFileContent(token, repoFullName, remotePath);
      if (remoteContent != null) {
        final localFile = File(p.join(_localFile.rootPath, remotePath));
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

  Future<void> recoverSpecificItem({
    required String token,
    required String repoFullName,
    required String commitSha,
    required String path,
    required bool isFolder,
  }) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final tree = await _githubApi.getTree(token, repoFullName, commitSha);
      if (tree != null && tree.entries != null) {
        final normalizedPath = isFolder && !path.endsWith('/') ? '$path/' : path;

        for (final item in tree.entries!) {
          if (item.type == 'blob' && (item.path!.endsWith('.md') || item.path!.endsWith('.gitkeep'))) {
            bool shouldRecover = false;
            if (isFolder) {
              if (item.path!.startsWith(normalizedPath)) shouldRecover = true;
            } else {
              if (item.path == path) shouldRecover = true;
            }

            if (shouldRecover && item.sha != null) {
              await _syncBlobLocally(token, repoFullName, item.sha!, item.path!);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Granular Recovery Failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncBlobLocally(String token, String repoFullName, String blobSha, String remotePath) async {
    try {
      final remoteContent = await _githubApi.getBlobContent(token, repoFullName, blobSha);
      if (remoteContent != null) {
        final localFile = File(p.join(_localFile.rootPath, remotePath));
        if (!await localFile.parent.exists()) await localFile.parent.create(recursive: true);
        await localFile.writeAsString(remoteContent);
      }
    } catch (_) {}
  }
}
