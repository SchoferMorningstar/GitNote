import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/file_system_node.dart';

class LocalFileService {
  String _rootPath = '';

  String get rootPath => _rootPath;

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${directory.path}/notes');
    if (!await notesDir.exists()) {
      await notesDir.create();
    }
    _rootPath = notesDir.path;
  }

  Future<List<FileSystemNode>> loadDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final files = dir.listSync();
    List<FileSystemNode> nodes = [];

    for (var file in files) {
      final stat = await file.stat();
      final name = p.basename(file.path);

      if (file is Directory) {
        nodes.add(FolderNode(
          path: file.path,
          name: name,
          lastModified: stat.modified,
        ));
      } else if (file is File && file.path.endsWith('.md')) {
        final content = await file.readAsString();
        nodes.add(NoteNode(
          path: file.path,
          name: name,
          lastModified: stat.modified,
          content: content,
        ));
      }
    }

    nodes.sort((a, b) {
      if (a is FolderNode && b is NoteNode) return -1;
      if (a is NoteNode && b is FolderNode) return 1;
      return b.lastModified.compareTo(a.lastModified);
    });

    return nodes;
  }

  Future<List<NoteNode>> loadAllNotesRecursive(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    List<NoteNode> nodes = [];
    final files = dir.listSync(recursive: true);

    for (var file in files) {
      if (file is File && file.path.endsWith('.md')) {
        final stat = await file.stat();
        final name = p.basename(file.path);
        final content = await file.readAsString();
        nodes.add(NoteNode(
          path: file.path,
          name: name,
          lastModified: stat.modified,
          content: content,
        ));
      }
    }
    return nodes;
  }

  String normalizeName(String content, {bool isFolder = false}) {
    if (content.isEmpty) return isFolder ? 'new_folder' : 'untitled.md';
    
    String baseText = content;
    if (!isFolder) {
      baseText = content.split('\n').first.trim().replaceAll(RegExp(r'^#+\s*'), '');
    }
    
    // Remove invalid file system characters and newlines, keep unicode
    String name = baseText.replaceAll(RegExp(r'[<>:"/\\|?*\n\r]'), '_').trim();
    if (name.isEmpty) name = isFolder ? 'new_folder' : 'untitled';
    
    return isFolder ? name : '$name.md';
  }

  String getUniqueFilePath(String directory, String desiredFilename, {String? ignorePath}) {
    String base = p.basenameWithoutExtension(desiredFilename);
    String ext = p.extension(desiredFilename);
    String currentPath = p.join(directory, desiredFilename);
    
    int counter = 1;
    while (File(currentPath).existsSync() && currentPath != ignorePath) {
      currentPath = p.join(directory, '${base}_$counter$ext');
      counter++;
    }
    return currentPath;
  }

  String getRelativePath(String fullPath) {
    if (fullPath.startsWith(_rootPath)) {
      String relative = fullPath.substring(_rootPath.length);
      if (relative.startsWith('/') || relative.startsWith('\\')) {
        relative = relative.substring(1);
      }
      return relative;
    }
    return p.basename(fullPath);
  }
}
