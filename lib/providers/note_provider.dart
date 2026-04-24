import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/services/local_file_service.dart';
import '../models/file_system_node.dart';
import '../providers/github_provider.dart';
import '../providers/settings_provider.dart';
import 'dart:io';

class NoteProvider with ChangeNotifier {
  final LocalFileService _localFile;

  List<FileSystemNode> _nodes = [];
  List<NoteNode> _allNotesRecursive = [];
  bool _isLoading = true;
  String _currentPath = '';
  SortType _sortType = SortType.name;
  SortOrder _sortOrder = SortOrder.ascending;
  String? _selectedTagFilter;

  NoteProvider(this._localFile) {
    _initAndLoad();
  }

  List<FileSystemNode> get nodes {
    if (_selectedTagFilter == null) return _nodes;
    return _allNotesRecursive.where((node) {
      return node.tags.contains(_selectedTagFilter);
    }).toList();
  }

  List<String> get availableTags {
    final tags = <String>{};
    for (var node in _allNotesRecursive) {
      tags.addAll(node.tags);
    }
    final sortedTags = tags.toList()..sort();
    return sortedTags;
  }

  String? get selectedTagFilter => _selectedTagFilter;

  void setTagFilter(String? tag) {
    if (_selectedTagFilter == tag) {
      _selectedTagFilter = null; // Toggle off
    } else {
      _selectedTagFilter = tag;
    }
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  String get currentPath => _currentPath;
  String get rootPath => _localFile.rootPath;
  String get currentDirName => p.basename(_currentPath);
  bool get isAtRoot => _currentPath == _localFile.rootPath;

  Future<void> _initAndLoad() async {
    _isLoading = true;
    notifyListeners();
    await _localFile.init();
    _currentPath = _localFile.rootPath;
    await _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    _isLoading = true;
    notifyListeners();
    _nodes = await _localFile.loadDirectory(path);
    _allNotesRecursive = await _localFile.loadAllNotesRecursive(path);
    _sortNodes();
    _isLoading = false;
    notifyListeners();
  }

  void applySorting(SortType type, SortOrder order) {
    _sortType = type;
    _sortOrder = order;
    _sortNodes();
    notifyListeners();
  }

  void _sortNodes() {
    _nodes.sort((a, b) {
      // Folders always first
      if (a is FolderNode && b is NoteNode) return -1;
      if (a is NoteNode && b is FolderNode) return 1;

      int comparison;
      if (_sortType == SortType.name) {
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        comparison = a.lastModified.compareTo(b.lastModified);
      }

      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }

  String generateNormalizedName(String content) => _localFile.normalizeName(content, isFolder: false);

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
    if (p.isWithin(rootPath, _currentPath) || parent == rootPath) {
      _currentPath = parent;
    } else {
      _currentPath = rootPath;
    }
    await _loadDirectory(_currentPath);
  }

  Future<void> createDirectory(String folderName, {required SettingsProvider settings, required GitHubProvider github}) async {
    final normalizedName = _localFile.normalizeName(folderName, isFolder: true);
    final dir = Directory(p.join(_currentPath, normalizedName));
    if (!await dir.exists()) {
      await dir.create();
      
      if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnCreate) {
        github.syncNote(
          token: settings.githubToken!,
          repoFullName: settings.selectedRepoFullName!,
          filename: p.join(_localFile.getRelativePath(dir.path), '.gitkeep'),
          content: '# Directory placeholder'
        );
      }
      await _loadDirectory(_currentPath);
    }
  }

  Future<void> saveNote(NoteNode? existingNote, String content, {required SettingsProvider settings, required GitHubProvider github}) async {
    final desiredFilename = _localFile.normalizeName(content, isFolder: false);
    String finalPath;

    if (existingNote != null) {
      final parentDir = Directory(existingNote.path).parent.path;
      final desiredPath = _localFile.getUniqueFilePath(parentDir, desiredFilename, ignorePath: existingNote.path);
      final file = File(existingNote.path);

      if (desiredPath != existingNote.path) {
        if (await file.exists()) {
          final newFile = await file.rename(desiredPath);
          await newFile.writeAsString(content);
        } else {
          await File(desiredPath).writeAsString(content);
        }
      } else {
        if (await file.exists()) await file.writeAsString(content);
      }
      finalPath = desiredPath;
    } else {
      finalPath = _localFile.getUniqueFilePath(_currentPath, desiredFilename);
      await File(finalPath).writeAsString(content);
    }

    if (settings.isGitHubConnected && settings.selectedRepoFullName != null) {
      final isNew = existingNote == null;
      final shouldPush = isNew ? settings.pushOnCreate : settings.pushOnSave;
      if (shouldPush) {
        github.syncNote(
          token: settings.githubToken!,
          repoFullName: settings.selectedRepoFullName!,
          filename: _localFile.getRelativePath(finalPath),
          content: content,
        );
      }
    }
    await _loadDirectory(_currentPath);
  }

  Future<void> moveNode(FileSystemNode node, String destinationFolderPath, {required SettingsProvider settings, required GitHubProvider github}) async {
    if (node.path == destinationFolderPath) return;
    final newPath = _localFile.getUniqueFilePath(destinationFolderPath, node.name);
    
    if (node is NoteNode) {
      final file = File(node.path);
      if (await file.exists()) {
        await file.rename(newPath);
        if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnSave) {
           github.syncNote(
             token: settings.githubToken!, 
             repoFullName: settings.selectedRepoFullName!, 
             filename: _localFile.getRelativePath(newPath), 
             content: node.content
           );
        }
      }
    } else if (node is FolderNode) {
      final dir = Directory(node.path);
      if (await dir.exists()) await dir.rename(newPath);
    }
    await _loadDirectory(_currentPath);
  }

  Future<void> deleteNode(FileSystemNode node, {required SettingsProvider settings, required GitHubProvider github}) async {
    if (node is NoteNode) {
      final file = File(node.path);
      if (await file.exists()) await file.delete();
      if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnDelete) {
        github.deleteNote(
          token: settings.githubToken!, 
          repoFullName: settings.selectedRepoFullName!, 
          filename: _localFile.getRelativePath(node.path)
        );
      }
    } else if (node is FolderNode) {
      final dir = Directory(node.path);
      if (await dir.exists()) await dir.delete(recursive: true);
      if (settings.isGitHubConnected && settings.selectedRepoFullName != null && settings.pushOnDelete) {
        github.deleteDirectory(
          token: settings.githubToken!,
          repoFullName: settings.selectedRepoFullName!,
          directoryPath: _localFile.getRelativePath(node.path)
        );
      }
    }
    await _loadDirectory(_currentPath);
  }
}
