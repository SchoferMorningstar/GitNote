abstract class FileSystemNode {
  final String path;
  final String name;
  final DateTime lastModified;

  FileSystemNode({
    required this.path,
    required this.name,
    required this.lastModified,
  });
}

class FolderNode extends FileSystemNode {
  FolderNode({
    required super.path,
    required super.name,
    required super.lastModified,
  });
}

class NoteNode extends FileSystemNode {
  String content;

  NoteNode({
    required super.path,
    required super.name,
    required super.lastModified,
    required this.content,
  });

  String get title {
    if (content.isEmpty) return 'Untitled';
    final firstLine = content.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Untitled';
    return firstLine.replaceAll(RegExp(r'^#+\s*'), '');
  }

  String get preview {
    final lines = content.split('\n');
    if (lines.length > 1) {
      return lines.sublist(1).where((line) => line.trim().isNotEmpty).join(' ').take(100);
    }
    return '';
  }

  List<String> get tags {
    final regex = RegExp(r'(?:^|\s)@([a-zA-Z0-9_-]+)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!.toLowerCase()).toSet().toList();
  }
}

extension StringExtension on String {
  String take(int length) {
    if (this.length <= length) return this;
    return '${substring(0, length)}...';
  }
}
