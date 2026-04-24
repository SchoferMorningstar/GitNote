import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart';
import '../models/file_system_node.dart';
import '../providers/github_provider.dart';
import '../providers/note_provider.dart';
import '../providers/settings_provider.dart';

class EditorScreen extends StatefulWidget {
  final NoteNode? note;

  const EditorScreen({super.key, this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isPreviewMode = false;
  int _forceRebuildId = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    final content = _controller.text;
    if (content.trim().isEmpty) {
      if (widget.note != null) {
        Provider.of<NoteProvider>(context, listen: false).deleteNode(
          widget.note!,
          settings: context.read<SettingsProvider>(),
          github: context.read<GitHubProvider>(),
        );
      }
      Navigator.pop(context);
      return;
    }

    Provider.of<NoteProvider>(context, listen: false).saveNote(
      widget.note, 
      content,
      settings: context.read<SettingsProvider>(),
      github: context.read<GitHubProvider>(),
    );
    Navigator.pop(context);
  }

  List<String> _extractTags(String content) {
    final regex = RegExp(r'(?:^|\s)@([a-zA-Z0-9_-]+)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!.toLowerCase()).toSet().toList();
  }

  void _showAddTagDialog() {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final availableTags = noteProvider.availableTags;
    final TextEditingController tagController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tagController,
                  decoration: const InputDecoration(
                    hintText: 'New tag name...',
                    prefixText: '@',
                  ),
                  autofocus: true,
                ),
                if (availableTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text('Existing Tags:', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: availableTags.map((tag) => ActionChip(
                      label: Text('@$tag'),
                      onPressed: () {
                        Navigator.pop(context, tag);
                      },
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (tagController.text.trim().isNotEmpty) {
                  Navigator.pop(context, tagController.text.trim());
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((selectedTag) {
      if (selectedTag != null && selectedTag is String) {
        final cleanTag = selectedTag.replaceAll('@', '');
        if (cleanTag.isNotEmpty) {
          final prefix = _controller.text.isEmpty || _controller.text.endsWith('\n') || _controller.text.endsWith(' ') ? '' : ' ';
          _insertMarkdown('$prefix@$cleanTag ');
          setState(() {
            _forceRebuildId++;
          });
        }
      }
    });
  }

  void _insertMarkdown(String prefix, [String suffix = '']) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.baseOffset == -1 || selection.extentOffset == -1) {
      // No cursor, just append
      _controller.text = text + prefix + suffix;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length - suffix.length);
      return;
    }

    final start = selection.start;
    final end = selection.end;
    
    final selectedText = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$prefix$selectedText$suffix');
    
    _controller.text = newText;
    
    if (selectedText.isEmpty) {
      _controller.selection = TextSelection.collapsed(offset: start + prefix.length);
    } else {
      _controller.selection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      );
    }
    
    _focusNode.requestFocus();
  }

  Widget _buildToolbar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          IconButton(icon: const Icon(Icons.format_bold), onPressed: () => _insertMarkdown('**', '**')),
          IconButton(icon: const Icon(Icons.format_italic), onPressed: () => _insertMarkdown('*', '*')),
          IconButton(icon: const Icon(Icons.format_strikethrough), onPressed: () => _insertMarkdown('~~', '~~')),
          const VerticalDivider(indent: 8, endIndent: 8),
          IconButton(icon: const Icon(Icons.title), onPressed: () => _insertMarkdown('# ')),
          IconButton(icon: const Icon(Icons.format_list_bulleted), onPressed: () => _insertMarkdown('- ')),
          IconButton(icon: const Icon(Icons.format_list_numbered), onPressed: () => _insertMarkdown('1. ')),
          const VerticalDivider(indent: 8, endIndent: 8),
          IconButton(icon: const Icon(Icons.format_quote), onPressed: () => _insertMarkdown('> ')),
          IconButton(icon: const Icon(Icons.code), onPressed: () => _insertMarkdown('`', '`')),
          IconButton(icon: const Icon(Icons.data_object), onPressed: () => _insertMarkdown('```\n', '\n```')),
          const VerticalDivider(indent: 8, endIndent: 8),
          IconButton(icon: const Icon(Icons.link), onPressed: () => _insertMarkdown('[', '](url)')),
          IconButton(icon: const Icon(Icons.image), onPressed: () => _insertMarkdown('![alt text](', ')')),
        ],
      ),
    );
  }

  Widget _buildTagsBar() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        final tags = _extractTags(value.text);
        
        return Container(
          height: 54,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              ...tags.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Chip(
                  label: Text('@$tag', style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                  side: BorderSide.none,
                ),
              )),
              ActionChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.add, size: 16), SizedBox(width: 4), Text('Add Tag')],
                ),
                onPressed: _showAddTagDialog,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                side: BorderSide.none,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final isLiveEditMode = context.watch<SettingsProvider>().isLiveEditMode;

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) {
            final currentFilename = noteProvider.generateNormalizedName(value.text);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPreviewMode ? 'Preview' : 'Edit Note',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  currentFilename,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isPreviewMode ? Icons.edit : Icons.preview),
            tooltip: _isPreviewMode ? 'Edit Mode' : 'Preview Markdown',
            onPressed: () {
              setState(() {
                _isPreviewMode = !_isPreviewMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save Note',
            onPressed: _saveNote,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isPreviewMode) _buildTagsBar(),
            if (!_isPreviewMode && !isLiveEditMode) _buildToolbar(),
            Expanded(
              child: _isPreviewMode
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Markdown(
                        data: _controller.text.isEmpty ? 'Nothing to preview' : _controller.text,
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        // Focus the end of the text if tapping empty space
                        if (!isLiveEditMode) {
                          _focusNode.requestFocus();
                          _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                        }
                      },
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: isLiveEditMode 
                          ? MarkdownEditor(
                              key: ValueKey(_forceRebuildId),
                              initialValue: _controller.text,
                              onChanged: (val) {
                                _controller.text = val;
                              },
                              style: const TextStyle(fontSize: 16, height: 1.5),
                              decoration: const InputDecoration(
                                hintText: '# Note Title\n\nStart typing your markdown here...',
                                border: InputBorder.none,
                              ),
                            )
                          : TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: '# Note Title\n\nStart typing your markdown here...',
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
