import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:github/github.dart' as gh;
import '../providers/github_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/note_provider.dart';
import 'commit_detail_screen.dart';

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
      final commits = await github.fetchCommits(settings.githubToken!, settings.selectedRepoFullName!);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommitDetailScreen(commit: commit),
      ),
    );
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
