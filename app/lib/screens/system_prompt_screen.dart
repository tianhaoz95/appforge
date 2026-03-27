import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SystemPromptScreen extends StatefulWidget {
  const SystemPromptScreen({super.key});

  @override
  State<SystemPromptScreen> createState() => _SystemPromptScreenState();
}

class _SystemPromptScreenState extends State<SystemPromptScreen> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    String initialText;
    if (settings.customSystemPrompt.isNotEmpty) {
      initialText = settings.customSystemPrompt;
    } else if (settings.useCompactPrompt) {
      initialText = settings.compactSystemPrompt;
    } else {
      initialText = settings.defaultSystemPrompt;
    }
    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revertToDefault({bool compact = false}) {
    final settings = context.read<SettingsProvider>();
    final prompt = compact ? settings.compactSystemPrompt : settings.defaultSystemPrompt;
    settings.setUseCompactPrompt(compact);
    settings.setCustomSystemPrompt('');
    setState(() {
      _controller.text = prompt;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reverted to ${compact ? "compact" : "normal"} default system prompt')),
    );
  }

  void _save() {
    final settings = context.read<SettingsProvider>();
    settings.setUseCompactPrompt(false);
    settings.setCustomSystemPrompt(_controller.text);
    setState(() {
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom system prompt saved')),
    );
  }

  Future<void> _showSaveDialog() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save System Prompt'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Prompt Name',
            hintText: 'e.g., Creative Assistant',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      settings.setUseCompactPrompt(false);
      await settings.saveNamedSystemPrompt(name.trim(), _controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as "$name"')),
      );
    }
  }

  void _applyNamedPrompt(String name, String prompt) {
    final settings = context.read<SettingsProvider>();
    settings.setUseCompactPrompt(false);
    settings.setCustomSystemPrompt(prompt);
    setState(() {
      _controller.text = prompt;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied "$name" system prompt')),
    );
  }

  void _deleteNamedPrompt(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Prompt'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      await settings.deleteNamedSystemPrompt(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Instructions'),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.save_as),
              onPressed: _showSaveDialog,
              tooltip: 'Save as New',
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
              tooltip: 'Save',
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit',
            ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final savedPrompts = settings.savedSystemPrompts;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Customize AI behavior', style: TextStyle(fontWeight: FontWeight.bold)),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'normal') {
                          _revertToDefault(compact: false);
                        } else if (value == 'compact') {
                          _revertToDefault(compact: true);
                        } else if (value.startsWith('apply:')) {
                          final name = value.substring(6);
                          _applyNamedPrompt(name, savedPrompts[name]!);
                        } else if (value.startsWith('delete:')) {
                          final name = value.substring(7);
                          _deleteNamedPrompt(name);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'normal',
                          child: ListTile(
                            leading: Icon(Icons.description_outlined),
                            title: Text('Normal Default'),
                            subtitle: Text('Full-featured instructions'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'compact',
                          child: ListTile(
                            leading: Icon(Icons.short_text),
                            title: Text('Compact Default'),
                            subtitle: Text('Optimized for local models'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (savedPrompts.isNotEmpty) ...[
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            enabled: false,
                            child: Text('SAVED PROMPTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          ...savedPrompts.keys.map((name) => PopupMenuItem(
                                value: 'apply:$name',
                                child: Row(
                                  children: [
                                    const Icon(Icons.label_outline, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(name)),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteNamedPrompt(name);
                                      },
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ],
                      child: TextButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.restore),
                        label: const Text('Revert to Default'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _isEditing
                      ? TextField(
                          controller: _controller,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: 'Enter custom system instructions here...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _controller.text.isEmpty
                                  ? 'No system prompt available yet. Start a conversation to initialize it.'
                                  : _controller.text,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
