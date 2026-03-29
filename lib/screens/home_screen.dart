import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/settings_provider.dart';
import '../providers/github_provider.dart';
import '../providers/note_provider.dart';
import '../models/file_system_node.dart';
import '../utils/merge_helper.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSync();
    });
  }

  void _initSync() {
    final settings = context.read<SettingsProvider>();
    final github = context.read<GitHubProvider>();
    final noteProvider = context.read<NoteProvider>();
    github.startAutoPull(settings, noteProvider);
  }

  void _showNewFolderDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final github = context.read<GitHubProvider>();
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Folder Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  context.read<NoteProvider>().createDirectory(
                    controller.text.trim(),
                    settings: settings,
                    github: github,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _createNote(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditorScreen(),
      ),
    );
  }

  Widget _buildNodeItem(BuildContext context, FileSystemNode node, NoteProvider noteProvider) {
    final isFolder = node is FolderNode;
    
    Widget content = Dismissible(
      key: Key(node.path),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (isFolder) {
           return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Folder?'),
              content: Text("Are you sure you want to delete '${node.name}' and all its contents?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ) ?? false;
        }
        return true;
      },
      onDismissed: (direction) {
        noteProvider.deleteNode(
          node,
          settings: context.read<SettingsProvider>(),
          github: context.read<GitHubProvider>(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isFolder ? 'Folder' : 'Note'} deleted')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: Icon(
            isFolder ? Icons.folder : Icons.description,
            size: 36,
            color: isFolder ? Colors.amber : Colors.blueGrey,
          ),
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  isFolder ? node.name : (node as NoteNode).title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isFolder && MergeHelper.hasConflicts((node as NoteNode).content))
                const Tooltip(
                  message: 'Merge Conflict Detected',
                  child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isFolder && (node as NoteNode).preview.isNotEmpty) ...[
                  Text(
                    node.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  DateFormat('MMM d, yyyy - h:mm a').format(node.lastModified),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          onTap: () {
            if (isFolder) {
              noteProvider.navigateInto(node.path);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditorScreen(note: node as NoteNode),
                ),
              );
            }
          },
        ),
      ),
    );

    // Make Node Draggable
    content = LongPressDraggable<FileSystemNode>(
      data: node,
      feedback: Material(
        elevation: 4,
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: content,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: content,
      ),
      child: content,
    );
    
    // Make Folder a Drag target
    if (isFolder) {
      return DragTarget<FileSystemNode>(
        onWillAcceptWithDetails: (details) => details.data.path != node.path,
        onAcceptWithDetails: (details) {
          noteProvider.moveNode(
            details.data, 
            node.path,
            settings: context.read<SettingsProvider>(),
            github: context.read<GitHubProvider>(),
          );
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            foregroundDecoration: candidateData.isNotEmpty
                ? BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: content,
          );
        },
      );
    }
    
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final github = context.watch<GitHubProvider>();
    
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        return Scaffold(
          appBar: AppBar(
            leading: noteProvider.isAtRoot
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => noteProvider.navigateUp(),
                  ),
            title: Text(noteProvider.isAtRoot ? 'GitNote' : noteProvider.currentDirName),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: noteProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : noteProvider.nodes.isEmpty
                  ? const Center(
                      child: Text(
                        'No notes yet.\nTap + to create one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: noteProvider.nodes.length,
                      itemBuilder: (context, index) => _buildNodeItem(context, noteProvider.nodes[index], noteProvider),
                    ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.95),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sync Button
                IconButton(
                  tooltip: 'Sync with GitHub',
                  onPressed: github.isSyncing 
                    ? null 
                    : () {
                      if (settings.isGitHubConnected && settings.selectedRepoFullName != null) {
                        github.pullLatestNotes(
                          token: settings.githubToken!,
                          repoFullName: settings.selectedRepoFullName!,
                          noteProvider: context.read<NoteProvider>(),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('GitHub not connected')),
                        );
                      }
                    },
                  icon: github.isSyncing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 28),
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const VerticalDivider(width: 24, indent: 16, endIndent: 16),
                // Create Button
                PopupMenuButton<int>(
                  tooltip: 'Create New',
                  offset: const Offset(0, -110),
                  onSelected: (item) {
                    if (item == 0) {
                      _createNote(context);
                    } else if (item == 1) {
                      _showNewFolderDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 0,
                      child: Row(children: [Icon(Icons.description), SizedBox(width: 8), Text('Create File')]),
                    ),
                    const PopupMenuItem(
                      value: 1,
                      child: Row(children: [Icon(Icons.folder), SizedBox(width: 8), Text('Create Folder')]),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.add_circle, size: 36, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
