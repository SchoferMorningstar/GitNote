import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:github/github.dart' as gh;
import 'package:http/http.dart' as http;

class GitHubApiService {
  Future<Map<String, dynamic>?> requestDeviceCode(String clientId) async {
    try {
      final response = await http.post(
        Uri.parse('https://github.com/login/device/code'),
        headers: {'Accept': 'application/json'},
        body: {'client_id': clientId, 'scope': 'repo user'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error requesting device code: $e');
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
          return data['access_token'];
        }
        if (data['error'] == 'authorization_pending') continue;
        if (data['error'] == 'expired_token' || data['error'] == 'access_denied') break;
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    }
    return null;
  }

  Future<gh.User?> verifyToken(String token) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final user = await client.users.getCurrentUser();
      client.dispose();
      return user;
    } catch (e) {
      debugPrint('GitHub Token Verification Failed: $e');
      return null;
    }
  }

  Future<List<gh.Repository>> fetchRepositories(String token) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final repos = await client.repositories.listRepositories().toList();
      client.dispose();
      return repos;
    } catch (e) {
      debugPrint('Failed to fetch repositories: $e');
      return [];
    }
  }

  Future<List<gh.RepositoryCommit>> fetchCommits(String token, String repoFullName) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final slug = gh.RepositorySlug.full(repoFullName);
      final commits = await client.repositories.listCommits(slug).take(20).toList();
      client.dispose();
      return commits;
    } catch (e) {
      debugPrint('Failed to fetch commits: $e');
      return [];
    }
  }

  Future<void> syncNote({
    required String token,
    required String repoFullName,
    required String filename,
    required String content,
  }) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final slug = gh.RepositorySlug.full(repoFullName);
      String? sha;
      try {
        final existing = await client.repositories.getContents(slug, filename);
        if (existing.file != null) sha = existing.file!.sha;
      } catch (_) {}

      final encodedContent = base64Encode(utf8.encode(content));
      if (sha != null) {
        await client.repositories.updateFile(slug, filename, 'Update $filename via GitNote', encodedContent, sha);
      } else {
        await client.repositories.createFile(slug, gh.CreateFile(path: filename, message: 'Create $filename via GitNote', content: encodedContent));
      }
      client.dispose();
    } catch (e) {
      debugPrint('Failed to sync note to GitHub: $e');
    }
  }

  Future<void> deleteNote({
    required String token,
    required String repoFullName,
    required String filename,
  }) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final slug = gh.RepositorySlug.full(repoFullName);
      final content = await client.repositories.getContents(slug, filename);
      if (content.file != null && content.file!.sha != null) {
        await client.repositories.deleteFile(slug, filename, 'Delete $filename via GitNote', content.file!.sha!, 'main');
      }
      client.dispose();
    } catch (e) {
      debugPrint('Failed to delete note from GitHub: $e');
    }
  }

  Future<void> deleteDirectory({
    required String token,
    required String repoFullName,
    required String directoryPath,
  }) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final slug = gh.RepositorySlug.full(repoFullName);
      final tree = await client.git.getTree(slug, 'main', recursive: true);
      
      if (tree.entries != null) {
        final normalizedDir = directoryPath.endsWith('/') ? directoryPath : '$directoryPath/';
        for (final item in tree.entries!) {
          if (item.type == 'blob' && item.path!.startsWith(normalizedDir)) {
            try {
              final content = await client.repositories.getContents(slug, item.path!);
              await client.repositories.deleteFile(slug, item.path!, 'Delete ${item.path} via GitNote', content.file!.sha!, 'main');
            } catch (_) {}
          }
        }
      }
      client.dispose();
    } catch (e) {
      debugPrint('Failed to delete directory: $e');
    }
  }

  Future<gh.GitTree?> getTree(String token, String repoFullName, String sha) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final slug = gh.RepositorySlug.full(repoFullName);
      final tree = await client.git.getTree(slug, sha, recursive: true);
      client.dispose();
      return tree;
    } catch (e) {
      debugPrint('Failed to get tree: $e');
      return null;
    }
  }

  Future<String?> getFileContent(String token, String repoFullName, String path) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final slug = gh.RepositorySlug.full(repoFullName);
      final contentResp = await client.repositories.getContents(slug, path);
      client.dispose();
      
      if (contentResp.file != null && contentResp.file!.content != null) {
        final rawContent = contentResp.file!.content!.replaceAll('\n', '');
        return utf8.decode(base64Decode(rawContent));
      }
    } catch (e) {
      debugPrint('Failed to get file content: $e');
    }
    return null;
  }

  Future<String?> getBlobContent(String token, String repoFullName, String sha) async {
    try {
      final client = gh.GitHub(auth: gh.Authentication.withToken(token));
      final slug = gh.RepositorySlug.full(repoFullName);
      final blob = await client.git.getBlob(slug, sha);
      client.dispose();
      
      if (blob.content != null) {
        // GitHub API returns blob content base64 encoded
        final rawContent = blob.content!.replaceAll('\n', '');
        return utf8.decode(base64Decode(rawContent));
      }
    } catch (e) {
      debugPrint('Failed to get blob content: $e');
    }
    return null;
  }
}
