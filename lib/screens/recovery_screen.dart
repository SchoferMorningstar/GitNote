import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:github/github.dart' as gh;
import '../providers/github_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/note_provider.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  List<gh.RepositoryCommit>? _commits;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  Future<void> _loadCommits() async {
    final settings = context.read<SettingsProvider>();
    final github = context.read<GitHubProvider>();
    
    if (settings.selectedRepoFullName != null) {
      final commits = await github.fetchCommits(settings.selectedRepoFullName!);
      setState(() {
        _commits = commits;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showRestoreDialog(gh.RepositoryCommit commit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restoration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to restore your repository to this state?'),
            const SizedBox(height: 16),
            const Text('WARNING:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const Text('This will overwrite all your current local notes with the versions from this commit.'),
            const SizedBox(height: 8),
            Text('Commit: ${commit.commit?.message ?? "No message"}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              _performRestore(commit.sha!);
            },
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(String sha) async {
    final settings = context.read<SettingsProvider>();
    final github = context.read<GitHubProvider>();
    final noteProvider = context.read<NoteProvider>();

    // Show Progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await github.restoreFromCommit(
        token: settings.githubToken!,
        repoFullName: settings.selectedRepoFullName!,
        sha: sha,
        noteProvider: noteProvider,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close progress
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Repository successfully restored!')),
        );
        Navigator.pop(context); // Go back home
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final github = context.watch<GitHubProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery System'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _commits == null || _commits!.isEmpty
              ? const Center(child: Text('No commits found or repository not connected.'))
              : ListView.builder(
                  itemCount: _commits!.length,
                  itemBuilder: (context, index) {
                    final commit = _commits![index];
                    final date = commit.commit?.author?.date;
                    final message = commit.commit?.message ?? 'No commit message';
                    final author = commit.commit?.author?.name ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          child: const Icon(Icons.commit, color: Colors.indigo),
                        ),
                        title: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('By $author', style: const TextStyle(fontSize: 12)),
                            if (date != null)
                              Text(DateFormat('MMM d, yyyy - HH:mm').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.settings_backup_restore, color: Colors.green),
                          onPressed: github.isSyncing ? null : () => _showRestoreDialog(commit),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
