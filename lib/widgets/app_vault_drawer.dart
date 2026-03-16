import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/micro_app_repository.dart';
import '../repositories/conversation_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'dart:io';

class AppVaultDrawer extends StatefulWidget {
  final Function(Map<String, dynamic> app)? onAppSelected;
  final Function(String conversationId, String title)? onConversationSelected;

  const AppVaultDrawer({super.key, this.onAppSelected, this.onConversationSelected});

  @override
  State<AppVaultDrawer> createState() => _AppVaultDrawerState();
}

class _AppVaultDrawerState extends State<AppVaultDrawer> {
  Future<List<Map<String, dynamic>>>? _appsFuture;
  Future<List<Map<String, dynamic>>>? _convsFuture;
  bool _isChatSelectionMode = false;
  bool _isAppSelectionMode = false;
  final Set<String> _selectedConversationIds = {};
  final Set<String> _selectedAppIds = {};
  bool _isOlderExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh futures when dependencies change (including repository notifications)
    // We use context.watch to trigger didChangeDependencies on notifyListeners()
    Provider.of<MicroAppRepository>(context);
    Provider.of<ConversationRepository>(context);
    Provider.of<AuthProvider>(context);
    Provider.of<SettingsProvider>(context);
    _refresh();
  }

  void _refresh() {
    final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
    final convRepository = Provider.of<ConversationRepository>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? 'local-user';
    
    setState(() {
      _appsFuture = appRepository.getAppsForOwner(userId);
      _convsFuture = convRepository.getConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Consumer2<AuthProvider, SettingsProvider>(
              builder: (context, auth, settings, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.asset(
                          'brand/logo.png',
                          height: 32,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.auto_awesome_motion, 
                            size: 32, 
                            color: Theme.of(context).colorScheme.primary
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AppVault',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        radius: 16,
                        backgroundImage: settings.localAvatarPath.isNotEmpty
                            ? FileImage(File(settings.localAvatarPath))
                            : null,
                        child: settings.localAvatarPath.isEmpty
                            ? Text(auth.user?.displayName?.substring(0, 1).toUpperCase() ?? 'U')
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              auth.user?.displayName ?? 'User',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              auth.user?.email ?? '',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildSectionHeader(
            title: 'Recent Chats',
            isSelectionMode: _isChatSelectionMode,
            selectedCount: _selectedConversationIds.length,
            onCancel: () => setState(() {
              _isChatSelectionMode = false;
              _selectedConversationIds.clear();
              _isOlderExpanded = false;
            }),
            onSelectAll: (allIds) => setState(() {
              if (_selectedConversationIds.length == allIds.length) {
                _selectedConversationIds.clear();
              } else {
                _selectedConversationIds.addAll(allIds);
              }
            }),
            onDelete: () => _confirmBulkDelete(context, 'chats'),
            allItemsFuture: _convsFuture,
            idKey: 'conversationId',
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _convsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final convs = snapshot.data ?? [];
              if (convs.isEmpty) {
                return const ListTile(title: Text('No history yet.', style: TextStyle(fontSize: 12)));
              }

              final recent = convs.take(3).toList();
              final older = convs.skip(3).toList();

              return Column(
                children: [
                  ...recent.map((conv) => _buildConversationTile(conv)),
                  if (older.isNotEmpty)
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        dense: true,
                        initiallyExpanded: _isOlderExpanded || _isChatSelectionMode,
                        onExpansionChanged: (val) {
                          if (!_isChatSelectionMode) {
                            setState(() => _isOlderExpanded = val);
                          }
                        },
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          'Older Chats (${older.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        leading: const Icon(Icons.history, size: 18),
                        children: older.map((conv) => _buildConversationTile(conv)).toList(),
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          _buildSectionHeader(
            title: 'Forged Apps',
            isSelectionMode: _isAppSelectionMode,
            selectedCount: _selectedAppIds.length,
            onCancel: () => setState(() {
              _isAppSelectionMode = false;
              _selectedAppIds.clear();
            }),
            onSelectAll: (allIds) => setState(() {
              if (_selectedAppIds.length == allIds.length) {
                _selectedAppIds.clear();
              } else {
                _selectedAppIds.addAll(allIds);
              }
            }),
            onDelete: () => _confirmBulkDelete(context, 'apps'),
            allItemsFuture: _appsFuture,
            idKey: 'appId',
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _appsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListTile(title: Text('Error: ${snapshot.error}'));
              }
              final apps = snapshot.data ?? [];
              if (apps.isEmpty) {
                return const ListTile(title: Text('No apps forged yet.'));
              }
              return Column(
                children: apps.map((app) => _buildAppTile(app)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required bool isSelectionMode,
    required int selectedCount,
    required VoidCallback onCancel,
    required Function(Set<String>) onSelectAll,
    required VoidCallback onDelete,
    required Future<List<Map<String, dynamic>>>? allItemsFuture,
    required String idKey,
  }) {
    if (!isSelectionMode) {
      return ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: allItemsFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final allIds = items.map((i) => i[idKey] as String).toSet();
        final isAllSelected = selectedCount == allIds.length && allIds.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: onCancel,
              ),
              title: Text(
                '$selectedCount Selected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: selectedCount == 0 ? null : onDelete,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => onSelectAll(allIds),
                      icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all, size: 16),
                      label: Text(
                        isAllSelected ? 'Deselect All' : 'Select All',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  Widget _buildAppTile(Map<String, dynamic> app) {
    final String id = app['appId'];
    final bool isSelected = _selectedAppIds.contains(id);
    final bool isPinned = (app['is_pinned'] ?? 0) == 1;

    return ListTile(
      dense: true,
      leading: _isAppSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedAppIds.add(id);
                  } else {
                    _selectedAppIds.remove(id);
                  }
                });
              },
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPinned)
                  Icon(Icons.push_pin, size: 12, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                _buildIcon(app['icon']),
              ],
            ),
      title: Text(
        app['name'] ?? 'Unnamed App',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('v${app['version']}', style: const TextStyle(fontSize: 11)),
      trailing: _isAppSelectionMode
          ? null
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) async {
                final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
                switch (value) {
                  case 'pin':
                    await appRepository.pinApp(id, !isPinned);
                    break;
                  case 'rename':
                    await _showRenameDialog(context, app);
                    break;
                  case 'delete':
                    await _confirmDelete(context, app);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: ListTile(
                    leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                    title: Text(isPinned ? 'Unpin' : 'Pin'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
      onTap: () {
        if (_isAppSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedAppIds.remove(id);
            } else {
              _selectedAppIds.add(id);
            }
          });
        } else {
          widget.onAppSelected?.call(app);
          Navigator.pop(context);
        }
      },
      onLongPress: () {
        if (!_isAppSelectionMode) {
          setState(() {
            _isAppSelectionMode = true;
            _selectedAppIds.add(id);
          });
        } else {
          _confirmDelete(context, app);
        }
      },
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, Map<String, dynamic> app) async {
    final controller = TextEditingController(text: app['name']);
    final bool? shouldRename = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Micro App'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'App Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (shouldRename == true && controller.text.trim().isNotEmpty && context.mounted) {
      final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
      await appRepository.renameApp(app['appId'], controller.text.trim());
    }
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final String id = conv['conversationId'];
    final bool isSelected = _selectedConversationIds.contains(id);

    return ListTile(
      dense: true,
      leading: _isChatSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedConversationIds.add(id);
                  } else {
                    _selectedConversationIds.remove(id);
                  }
                });
              },
            )
          : const Icon(Icons.chat_bubble_outline, size: 20),
      title: Text(
        conv['title'] ?? 'Untitled Chat',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        if (_isChatSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedConversationIds.remove(id);
            } else {
              _selectedConversationIds.add(id);
            }
          });
        } else {
          widget.onConversationSelected?.call(
            id,
            conv['title'] ?? 'Untitled Chat',
          );
          Navigator.pop(context);
        }
      },
      onLongPress: () {
        if (!_isChatSelectionMode) {
          setState(() {
            _isChatSelectionMode = true;
            _selectedConversationIds.add(id);
            _isOlderExpanded = true;
          });
        } else {
          _confirmDeleteConversation(context, conv);
        }
      },
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
    );
  }

  Future<void> _confirmBulkDelete(BuildContext context, String type) async {
    final int count = type == 'chats' ? _selectedConversationIds.length : _selectedAppIds.length;
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count $type?'),
        content: Text('Are you sure you want to delete the selected $type? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      if (type == 'chats' && _selectedConversationIds.isNotEmpty) {
        final convRepository = Provider.of<ConversationRepository>(context, listen: false);
        await convRepository.deleteConversations(_selectedConversationIds.toList());
        setState(() {
          _isChatSelectionMode = false;
          _selectedConversationIds.clear();
        });
      } else if (type == 'apps' && _selectedAppIds.isNotEmpty) {
        final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
        await appRepository.deleteApps(_selectedAppIds.toList());
        setState(() {
          _isAppSelectionMode = false;
          _selectedAppIds.clear();
        });
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> app) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Micro App?'),
        content: Text('Are you sure you want to delete "${app['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
      await appRepository.deleteApp(app['appId']);
    }
  }

  Future<void> _confirmDeleteConversation(BuildContext context, Map<String, dynamic> conv) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: Text('Are you sure you want to delete "${conv['title'] ?? 'Untitled Chat'}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final convRepository = Provider.of<ConversationRepository>(context, listen: false);
      await convRepository.deleteConversation(conv['conversationId']);
    }
  }

  Widget _buildIcon(String? icon) {
    if (icon == null || icon.isEmpty) return const Icon(Icons.apps, size: 20);
    switch (icon) {
      case 'rocket': return const Icon(Icons.rocket_launch, size: 20);
      case 'speed': return const Icon(Icons.speed, size: 20);
      case 'bolt': return const Icon(Icons.bolt, size: 20);
      default: return Text(icon, style: const TextStyle(fontSize: 20));
    }
  }
}
