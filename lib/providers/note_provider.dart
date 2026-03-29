import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/github_provider.dart';
import '../providers/settings_provider.dart';
import '../models/file_system_node.dart';

class NoteProvider with ChangeNotifier {
  List<FileSystemNode> _nodes = [];
  bool _isLoading = true;
  String _currentPath = '';
  String _rootPath = '';

  List<FileSystemNode> get nodes => _nodes;
  bool get isLoading => _isLoading;
  String get currentPath => _currentPath;
  String get rootPath => _rootPath;
  String get currentDirName => p.basename(_currentPath);
  bool get isAtRoot => _currentPath == _rootPath;

  NoteProvider() {
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    _isLoading = true;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${directory.path}/notes');
      
      if (!await notesDir.exists()) {
        await notesDir.create();
      }
      
      _rootPath = notesDir.path;
      _currentPath = _rootPath;
      
      await _loadDirectory(_currentPath);
    } catch (e) {
      debugPrint("Error loading notes: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDirectory(String path) async {
    _isLoading = true;
    notifyListeners();

    try {
      final dir = Directory(path);
      final files = dir.listSync();
      _nodes = [];

      for (var file in files) {
        final stat = await file.stat();
        final name = p.basename(file.path);

        if (file is Directory) {
          _nodes.add(FolderNode(
            path: file.path,
            name: name,
            lastModified: stat.modified,
          ));
        } else if (file is File && file.path.endsWith('.md')) {
          final content = await file.readAsString();
          _nodes.add(NoteNode(
            path: file.path,
            name: name,
            lastModified: stat.modified,
            content: content,
          ));
        }
      }

      _nodes.sort((a, b) {
        if (a is FolderNode && b is NoteNode) return -1;
        if (a is NoteNode && b is FolderNode) return 1;
        return b.lastModified.compareTo(a.lastModified);
      });
    } catch (e) {
      debugPrint("Error loading directory: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadDirectory(_currentPath);
  }

  Future<void> navigateInto(String path) async {
    _currentPath = path;
    await _loadDirectory(_currentPath);
  }

  Future<void> navigateUp() async {
    if (isAtRoot) return;
    final parent = Directory(_currentPath).parent.path;
    if (p.isWithin(_rootPath, _currentPath) || parent == _rootPath) {
      _currentPath = parent;
      await _loadDirectory(_currentPath);
    } else {
      _currentPath = _rootPath;
      await _loadDirectory(_currentPath);
    }
  }

  Future<void> createDirectory(String folderName, {required SettingsProvider settings, required GitHubProvider github}) async {
    try {
      final normalizedFolderName = folderName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
      final dir = Directory(p.join(_currentPath, normalizedFolderName.isEmpty ? 'new_folder' : normalizedFolderName));
      if (!await dir.exists()) {
        await dir.create();
        
        if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnCreate) {
          final relativeDirPath = _getRelativePath(dir.path);
          github.syncNote(
            token: settings.githubToken!,
            repoFullName: settings.selectedRepoFullName!,
            filename: p.join(relativeDirPath, '.gitkeep'),
            content: '# Directory placeholder'
          );
        }

        await _loadDirectory(_currentPath);
      }
    } catch (e) {
      debugPrint("Error creating directory: $e");
    }
  }

  String generateNormalizedName(String content) {
    if (content.isEmpty) return 'untitled.md';
    final firstLine = content.split('\n').first.trim().replaceAll(RegExp(r'^#+\s*'), '');
    if (firstLine.isEmpty) return 'untitled.md';

    String baseName = firstLine.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    baseName = baseName.replaceAll(RegExp(r'^_+|_+$'), '');
    if (baseName.isEmpty) baseName = 'untitled';
    return '$baseName.md';
  }

  String _getUniqueFilePath(String directory, String desiredFilename, {String? ignorePath}) {
    String base = p.basenameWithoutExtension(desiredFilename);
    const String ext = '.md';
    String currentPath = p.join(directory, desiredFilename);
    
    int counter = 1;
    while (File(currentPath).existsSync() && currentPath != ignorePath) {
      currentPath = p.join(directory, '${base}_$counter$ext');
      counter++;
    }
    return currentPath;
  }

  String _getRelativePath(String fullPath) {
    if (fullPath.startsWith(_rootPath)) {
      String relative = fullPath.substring(_rootPath.length);
      if (relative.startsWith('/') || relative.startsWith('\\')) {
        relative = relative.substring(1);
      }
      return relative;
    }
    return p.basename(fullPath);
  }

  Future<void> saveNote(NoteNode? existingNote, String content, {required SettingsProvider settings, required GitHubProvider github}) async {
    try {
      final desiredFilename = generateNormalizedName(content);
      String finalPath;

      if (existingNote != null) {
        finalPath = await _handleExistingNoteSave(existingNote, content, desiredFilename);
      } else {
        finalPath = await _handleNewNoteSave(content, desiredFilename);
      }

      // Sync to GitHub if necessary
      if (settings.isGitHubConnected && settings.selectedRepoFullName != null) {
        final isNew = existingNote == null;
        final shouldPush = isNew ? settings.pushOnCreate : settings.pushOnSave;
        
        if (shouldPush) {
          await github.syncNote(
            token: settings.githubToken!,
            repoFullName: settings.selectedRepoFullName!,
            filename: _getRelativePath(finalPath),
            content: content,
          );
        }
      }

      await _loadDirectory(_currentPath);
    } catch (e) {
      debugPrint("Error saving note: $e");
    }
  }

  Future<String> _handleExistingNoteSave(NoteNode existingNote, String content, String desiredFilename) async {
    final parentDir = Directory(existingNote.path).parent.path;
    final desiredPath = _getUniqueFilePath(parentDir, desiredFilename, ignorePath: existingNote.path);
    final file = File(existingNote.path);

    if (desiredPath != existingNote.path) {
      if (await file.exists()) {
        final newFile = await file.rename(desiredPath);
        await newFile.writeAsString(content);
      } else {
        await File(desiredPath).writeAsString(content);
      }
    } else {
      if (await file.exists()) {
        await file.writeAsString(content);
      }
    }
    return desiredPath;
  }

  Future<String> _handleNewNoteSave(String content, String desiredFilename) async {
    final newPath = _getUniqueFilePath(_currentPath, desiredFilename);
    await File(newPath).writeAsString(content);
    return newPath;
  }

  Future<void> moveNode(FileSystemNode node, String destinationFolderPath, {required SettingsProvider settings, required GitHubProvider github}) async {
    try {
      if (node.path == destinationFolderPath) return;
      
      final newPath = _getUniqueFilePath(destinationFolderPath, node.name);
      
      if (node is NoteNode) {
        final file = File(node.path);
        if (await file.exists()) {
          await file.rename(newPath);
          if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnSave) {
             github.syncNote(
               token: settings.githubToken!, 
               repoFullName: settings.selectedRepoFullName!, 
               filename: _getRelativePath(newPath), 
               content: node.content
             );
          }
        }
      } else if (node is FolderNode) {
        final dir = Directory(node.path);
        if (await dir.exists()) await dir.rename(newPath);
      }
      
      await _loadDirectory(_currentPath);
    } catch (e) {
      debugPrint("Error moving node: $e");
    }
  }

  Future<void> deleteNode(FileSystemNode node, {required SettingsProvider settings, required GitHubProvider github}) async {
    try {
      if (node is NoteNode) {
        final file = File(node.path);
        if (await file.exists()) await file.delete();
        if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnDelete) {
          github.deleteNote(
            token: settings.githubToken!, 
            repoFullName: settings.selectedRepoFullName!, 
            filename: _getRelativePath(node.path)
          );
        }
      } else if (node is FolderNode) {
        final dir = Directory(node.path);
        if (await dir.exists()) await dir.delete(recursive: true);
        if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnDelete) {
          github.deleteDirectory(
            token: settings.githubToken!,
            repoFullName: settings.selectedRepoFullName!,
            directoryPath: _getRelativePath(node.path)
          );
        }
      }

      await _loadDirectory(_currentPath);
    } catch (e) {
      debugPrint("Error deleting node: $e");
    }
  }
}
