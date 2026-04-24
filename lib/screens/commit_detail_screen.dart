import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:github/github.dart' as gh;
import '../providers/github_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/note_provider.dart';

class CommitDetailScreen extends StatefulWidget {
  final gh.RepositoryCommit commit;

  const CommitDetailScreen({super.key, required this.commit});

  @override
  State<CommitDetailScreen> createState() => _CommitDetailScreenState();
}

class _CommitDetailScreenState extends State<CommitDetailScreen> {
  bool _isLoading = true;
  List<gh.GitTreeEntry> _missingItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTree();
    });
  }

  Future<void> _loadTree() async {
    final settings = context.read<SettingsProvider>();
    final github = context.read<GitHubProvider>();
    final noteProvider = context.read<NoteProvider>();

    if (settings.selectedRepoFullName == null || settings.githubToken == null) return;

    final tree = await github.getTree(
      settings.githubToken!, 
      settings.selectedRepoFullName!, 
      widget.commit.sha!
    );

    if (tree != null && tree.entries != null) {
      final missing = <gh.GitTreeEntry>[];
      for (final entry in tree.entries!) {
        if (entry.path!.endsWith('.md') || entry.path!.endsWith('.gitkeep')) {
          final isFolder = entry.path!.endsWith('.gitkeep');
          final targetPath = isFolder 
              ? p.dirname(entry.path!) 
              : entry.path!;
          
          final localPath = p.join(noteProvider.rootPath, targetPath);
          final exists = isFolder 
              ? await Directory(localPath).exists()
              : await File(localPath).exists();

          if (!exists) {
            missing.add(entry);
          }
        }
      }
      
      setState(() {
        _missingItems = missing;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _recoverItem(gh.GitTreeEntry entry) async {
    final settings = context.read<SettingsProvider>();
    final github = context.read<GitHubProvider>();
    
    final isFolder = entry.path!.endsWith('.gitkeep');
    final targetPath = isFolder ? p.dirname(entry.path!) : entry.path!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await github.recoverItem(
        token: settings.githubToken!,
        repoFullName: settings.selectedRepoFullName!,
        commitSha: widget.commit.sha!,
        path: targetPath,
        isFolder: isFolder,
        onSyncComplete: () => context.read<NoteProvider>().refresh(),
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully recovered $targetPath')),
        );
        _loadTree(); // Refresh list to remove recovered items
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovery failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Items'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _missingItems.isEmpty
              ? const Center(child: Text('No deleted items found in this commit.'))
              : ListView.builder(
                  itemCount: _missingItems.length,
                  itemBuilder: (context, index) {
                    final entry = _missingItems[index];
                    final isFolder = entry.path!.endsWith('.gitkeep');
                    final displayPath = isFolder ? p.dirname(entry.path!) : entry.path!;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          isFolder ? Icons.folder : Icons.description,
                          color: isFolder ? Colors.amber : Colors.blueGrey,
                          size: 32,
                        ),
                        title: Text(displayPath, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _recoverItem(entry),
                          icon: const Icon(Icons.restore),
                          label: const Text('Recover'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
