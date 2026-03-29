import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/micro_app_repository.dart';
import '../repositories/conversation_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'app_vault_title.dart';
import '../theme.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Consumer2<AuthProvider, SettingsProvider>(
              builder: (context, auth, settings, _) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const GradientIcon(icon: Icons.auto_awesome_motion, size: 28),
                        const SizedBox(width: 10),
                        const GradientText(
                          'AppVault',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            radius: 14,
                            backgroundImage: settings.localAvatarPath.isNotEmpty
                                ? FileImage(File(settings.localAvatarPath))
                                : null,
                            child: settings.localAvatarPath.isEmpty
                                ? Text(
                                    auth.user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
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
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _buildSectionHeader(
            title: const Text(
              'Recent Chats',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
            title: const AppVaultTitle(),
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
    required Widget title,
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
        title: title,
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
    final String? screenshot = app['screenshot_blob'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
              : BorderSide(color: Theme.of(context).dividerTheme.color ?? Colors.transparent, width: 0.5),
        ),
        child: InkWell(
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
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: screenshot != null && screenshot.isNotEmpty
                        ? Image.memory(
                            base64Decode(screenshot),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(app),
                          )
                        : _buildFallbackThumbnail(app),
                  ),
                  if (_isAppSelectionMode)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Checkbox(
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
                      ),
                    ),
                  if (isPinned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.push_pin, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app['name'] ?? 'Unnamed App',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'v${app['version']}',
                            style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                    if (!_isAppSelectionMode)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(Map<String, dynamic> app) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Center(
        child: _buildIcon(app['icon'], size: 40),
      ),
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

  Widget _buildIcon(String? icon, {double size = 20}) {
    if (icon == null || icon.isEmpty) return Icon(Icons.apps, size: size);
    switch (icon) {
      case 'rocket': return Icon(Icons.rocket_launch, size: size);
      case 'speed': return Icon(Icons.speed, size: size);
      case 'bolt': return Icon(Icons.bolt, size: size);
      default: return Text(icon, style: TextStyle(fontSize: size));
    }
  }
}
