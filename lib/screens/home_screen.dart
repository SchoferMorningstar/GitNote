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
    noteProvider.applySorting(settings.sortType, settings.sortOrder);
    github.startAutoPull(settings, () => noteProvider.refresh());
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort by',
                onSelected: (value) async {
                  final s = context.read<SettingsProvider>();
                  final np = context.read<NoteProvider>();
                  SortType type = s.sortType;
                  SortOrder order = s.sortOrder;

                  if (value == 'name_asc') { type = SortType.name; order = SortOrder.ascending; }
                  else if (value == 'name_desc') { type = SortType.name; order = SortOrder.descending; }
                  else if (value == 'time_desc') { type = SortType.time; order = SortOrder.descending; }
                  else if (value == 'time_asc') { type = SortType.time; order = SortOrder.ascending; }

                  await s.setSortType(type);
                  await s.setSortOrder(order);
                  np.applySorting(type, order);
                },
                itemBuilder: (context) {
                  final s = context.read<SettingsProvider>();
                  return [
                    PopupMenuItem(
                      value: 'name_asc',
                      child: Row(children: [
                        Icon(Icons.sort_by_alpha, color: s.sortType == SortType.name && s.sortOrder == SortOrder.ascending ? Theme.of(context).colorScheme.primary : null),
                        const SizedBox(width: 8),
                        const Text('Name (A-Z)'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'name_desc',
                      child: Row(children: [
                        Icon(Icons.sort_by_alpha, color: s.sortType == SortType.name && s.sortOrder == SortOrder.descending ? Theme.of(context).colorScheme.primary : null),
                        const SizedBox(width: 8),
                        const Text('Name (Z-A)'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'time_desc',
                      child: Row(children: [
                        Icon(Icons.access_time, color: s.sortType == SortType.time && s.sortOrder == SortOrder.descending ? Theme.of(context).colorScheme.primary : null),
                        const SizedBox(width: 8),
                        const Text('Newest First'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'time_asc',
                      child: Row(children: [
                        Icon(Icons.access_time, color: s.sortType == SortType.time && s.sortOrder == SortOrder.ascending ? Theme.of(context).colorScheme.primary : null),
                        const SizedBox(width: 8),
                        const Text('Oldest First'),
                      ]),
                    ),
                  ];
                },
              ),
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (noteProvider.availableTags.isNotEmpty)
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
                        ),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: noteProvider.availableTags.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final tag = noteProvider.availableTags[index];
                            final isSelected = noteProvider.selectedTagFilter == tag;
                            return ChoiceChip(
                              label: Text('@$tag'),
                              selected: isSelected,
                              onSelected: (selected) {
                                noteProvider.setTagFilter(tag);
                              },
                            );
                          },
                        ),
                      ),
                    Expanded(
                      child: noteProvider.nodes.isEmpty
                          ? Center(
                              child: Text(
                                noteProvider.selectedTagFilter != null
                                    ? 'No notes found for @${noteProvider.selectedTagFilter}'
                                    : 'No notes yet.\nTap + to create one!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: noteProvider.nodes.length,
                              itemBuilder: (context, index) => _buildNodeItem(context, noteProvider.nodes[index], noteProvider),
                            ),
                    ),
                  ],
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
                          onSyncComplete: () => context.read<NoteProvider>().refresh(),
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
