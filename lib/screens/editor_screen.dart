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
  late String _content;
  late TextEditingController _fallbackController;
  bool _isPreviewMode = false;
  bool _isLiveEditMode = false;

  @override
  void initState() {
    super.initState();
    _content = widget.note?.content ?? '';
    _fallbackController = TextEditingController(text: _content);
    _fallbackController.addListener(() {
      setState(() {
        _content = _fallbackController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isLiveEditMode = context.watch<SettingsProvider>().isLiveEditMode;
    if (_isLiveEditMode) {
      _isPreviewMode = false;
    }
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  void _saveNote() {
    if (_content.trim().isEmpty) {
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
      _content,
      settings: context.read<SettingsProvider>(),
      github: context.read<GitHubProvider>(),
    );
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final currentFilename = noteProvider.generateNormalizedName(_content);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLiveEditMode ? 'Live Editor' : (_isPreviewMode ? 'Preview' : 'Edit Note'),
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
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_isLiveEditMode)
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLiveEditMode
              ? MarkdownEditor(
                  initialValue: _content,
                  onChanged: (val) {
                    setState(() {
                      _content = val;
                    });
                  },
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: '# Note Title\n\nStart typing your markdown here...',
                    border: InputBorder.none,
                  ),
                )
              : (_isPreviewMode
                  ? Markdown(
                      data: _content,
                    )
                  : TextField(
                      controller: _fallbackController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: '# Note Title\n\nStart typing your markdown here...',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    )),
        ),
      ),
    );
  }
}
