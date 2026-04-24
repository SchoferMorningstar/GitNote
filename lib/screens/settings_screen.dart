import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:github/github.dart' as gh;
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../providers/github_provider.dart';
import '../config/app_config.dart';
import 'recovery_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showDeviceFlowDialog(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final ghp = context.read<GitHubProvider>();
    final clientId = settings.githubClientId;

    if (clientId == null || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a GitHub Client ID first.')),
      );
      return;
    }

    final deviceCodeData = await ghp.requestDeviceCode(clientId);
    if (deviceCodeData == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start GitHub Activation.')),
        );
      }
      return;
    }

    final userCode = deviceCodeData['user_code'];
    final verificationUri = deviceCodeData['verification_uri'];
    final deviceCode = deviceCodeData['device_code'];
    final interval = deviceCodeData['interval'] ?? 5;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub Activation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    userCode,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: userCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(verificationUri),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open GitHub Activation'),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Waiting for authorization...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Start polling in background
    final accessToken = await ghp.pollForToken(clientId, deviceCode, interval);
    if (accessToken != null) {
      final user = await ghp.verifyToken(accessToken);
      if (user != null) {
        await settings.setGitHubAuth(accessToken, user.login!, user.avatarUrl!);
      }
      if (context.mounted) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub Connected Successfully!')),
        );
      }
    }
  }

  void _showRepoPickerDialog(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final github = context.read<GitHubProvider>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select Repository', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: FutureBuilder<List<gh.Repository>>(
                  future: github.fetchRepositories(settings.githubToken!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No repositories found.'));
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final repo = snapshot.data![index];
                        return ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(repo.fullName),
                          subtitle: Text(repo.description.isEmpty 
                              ? 'No description' 
                              : repo.description),
                          selected: settings.selectedRepoFullName == repo.fullName,
                          onTap: () {
                            settings.setSelectedRepo(repo.fullName);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Theme'),
                  subtitle: const Text('Switch between light and dark mode'),
                  value: settings.isDarkMode,
                  onChanged: (value) => settings.toggleTheme(value),
                  secondary: Icon(settings.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                ),
                SwitchListTile(
                  title: const Text('Live Edit Mode'),
                  subtitle: const Text('Apply markdown formatting instantly while typing'),
                  value: settings.isLiveEditMode,
                  onChanged: (value) => settings.toggleLiveEdit(value),
                  secondary: const Icon(Icons.edit_document),
                ),
              ],
            ),
          ),
          
          _buildSectionHeader(context, 'GitHub Synchronization'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                if (!settings.isGitHubConnected)
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Login with GitHub'),
                    subtitle: const Text('Secure browser authentication'),
                    onTap: () => _showDeviceFlowDialog(context),
                    trailing: const Icon(Icons.chevron_right),
                  )
                else ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: settings.githubAvatarUrl != null 
                          ? NetworkImage(settings.githubAvatarUrl!) 
                          : null,
                      child: settings.githubAvatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text('Connected as ${settings.githubUsername}'),
                    subtitle: const Text('Tap to logout'),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Logout?'),
                          content: const Text('Are you sure you want to disconnect your GitHub account?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        settings.clearGitHubAuth();
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: const Text('Target Repository'),
                    subtitle: Text(settings.selectedRepoFullName ?? 'No repository selected'),
                    onTap: () => _showRepoPickerDialog(context),
                    trailing: const Icon(Icons.edit),
                  ),
                ],
              ],
            ),
          ),

          if (settings.isGitHubConnected && settings.selectedRepoFullName != null) ...[
            _buildSectionHeader(context, 'Advanced Recovery'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.indigo),
                title: const Text('Recovery System'),
                subtitle: const Text('Restore your notes from a previous GitHub commit'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const RecoveryScreen()));
                },
              ),
            ),

            _buildSectionHeader(context, 'Sync Preferences'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Push on Save'),
                    subtitle: const Text('Upload changes when you edit a note'),
                    value: settings.pushOnSave,
                    onChanged: settings.togglePushOnSave,
                    secondary: const Icon(Icons.save_alt),
                  ),
                  SwitchListTile(
                    title: const Text('Push on Create'),
                    subtitle: const Text('Instantly sync new notes to GitHub'),
                    value: settings.pushOnCreate,
                    onChanged: settings.togglePushOnCreate,
                    secondary: const Icon(Icons.add_circle_outline),
                  ),
                  SwitchListTile(
                    title: const Text('Push on Delete'),
                    subtitle: const Text('Remove from GitHub when deleted locally'),
                    value: settings.pushOnDelete,
                    onChanged: settings.togglePushOnDelete,
                    secondary: const Icon(Icons.delete_outline),
                  ),
                  SwitchListTile(
                    title: const Text('Auto Pull'),
                    subtitle: const Text('Check for remote changes in background'),
                    value: settings.autoPull,
                    onChanged: settings.toggleAutoPull,
                    secondary: const Icon(Icons.sync),
                  ),
                  if (settings.autoPull)
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Auto Pull Interval'),
                      subtitle: Text('${settings.autoPullInterval} minutes'),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final controller = TextEditingController(text: settings.autoPullInterval.toString());
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Pull Interval (Min 15m)'),
                            content: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Minutes'),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  final val = int.tryParse(controller.text) ?? 15;
                                  settings.setAutoPullInterval(val);
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
          
          if (AppConfig.tipUrl.isNotEmpty) ...[
            _buildSectionHeader(context, 'Support the Developer'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pink),
                title: const Text('Tip the Developer'),
                subtitle: const Text('Buy me a coffee if you like this app!'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  final url = Uri.parse(AppConfig.tipUrl);
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open the tip link. Please check your browser.')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
          
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Opacity(
              opacity: 0.5,
              child: Text('GitNote 2.0\nProfessional Markdown Editor', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
