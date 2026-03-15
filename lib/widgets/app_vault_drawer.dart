import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/micro_app_repository.dart';
import '../repositories/conversation_repository.dart';
import '../providers/auth_provider.dart';

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
  bool _isSelectionMode = false;
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) => Column(
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
                        child: Text(auth.user?.displayName?.substring(0, 1).toUpperCase() ?? 'U'),
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
          if (!_isSelectionMode)
            const ListTile(
              title: Text(
                'Recent Chats',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          else
            _buildSelectionModeHeader(),
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
                        initiallyExpanded: _isOlderExpanded || _isSelectionMode,
                        onExpansionChanged: (val) {
                          if (!_isSelectionMode) {
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
          const ListTile(
            title: Text(
              'Forged Apps',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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

  Widget _buildAppTile(Map<String, dynamic> app) {
    final String id = app['appId'];
    final bool isSelected = _selectedAppIds.contains(id);

    return ListTile(
      dense: true,
      leading: _isSelectionMode
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
          : Icon(_getIcon(app['icon']), size: 20),
      title: Text(
        app['name'] ?? 'Unnamed App',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('v${app['version']}', style: const TextStyle(fontSize: 11)),
      onTap: () {
        if (_isSelectionMode) {
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
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedAppIds.add(id);
          });
        } else {
          _confirmDelete(context, app);
        }
      },
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
    );
  }

  Widget _buildSelectionModeHeader() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_convsFuture ?? Future.value([]), _appsFuture ?? Future.value([])]),
      builder: (context, snapshot) {
        final convs = snapshot.data?[0] as List<Map<String, dynamic>>? ?? [];
        final apps = snapshot.data?[1] as List<Map<String, dynamic>>? ?? [];
        
        final allConvIds = convs.map((c) => c['conversationId'] as String).toSet();
        final allAppIds = apps.map((a) => a['appId'] as String).toSet();
        
        final totalSelected = _selectedConversationIds.length + _selectedAppIds.length;
        final totalItems = allConvIds.length + allAppIds.length;
        final isAllSelected = totalSelected == totalItems && totalItems > 0;

        return ListTile(
          dense: true,
          title: Text(
            '$totalSelected Selected',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _isSelectionMode = false;
              _selectedConversationIds.clear();
              _selectedAppIds.clear();
              _isOlderExpanded = false;
            }),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    if (isAllSelected) {
                      _selectedConversationIds.clear();
                      _selectedAppIds.clear();
                    } else {
                      _selectedConversationIds.addAll(allConvIds);
                      _selectedAppIds.addAll(allAppIds);
                    }
                  });
                },
                child: Text(isAllSelected ? 'Deselect All' : 'Select All'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: totalSelected == 0 ? null : () => _confirmBulkDelete(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final String id = conv['conversationId'];
    final bool isSelected = _selectedConversationIds.contains(id);

    return ListTile(
      dense: true,
      leading: _isSelectionMode
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
        if (_isSelectionMode) {
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
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedConversationIds.add(id);
            _isOlderExpanded = true;
          });
        } else {
          _confirmDeleteConversation(context, conv);
        }
      },
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
    );
  }

  Future<void> _confirmBulkDelete(BuildContext context) async {
    final total = _selectedConversationIds.length + _selectedAppIds.length;
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $total Items?'),
        content: const Text('Are you sure you want to delete the selected items? This action cannot be undone.'),
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
      if (_selectedConversationIds.isNotEmpty) {
        final convRepository = Provider.of<ConversationRepository>(context, listen: false);
        await convRepository.deleteConversations(_selectedConversationIds.toList());
      }
      if (_selectedAppIds.isNotEmpty) {
        final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
        await appRepository.deleteApps(_selectedAppIds.toList());
      }
      setState(() {
        _isSelectionMode = false;
        _selectedConversationIds.clear();
        _selectedAppIds.clear();
      });
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

  IconData _getIcon(String? iconName) {
    switch (iconName) {
      case 'rocket': return Icons.rocket_launch;
      case 'speed': return Icons.speed;
      case 'bolt': return Icons.bolt;
      default: return Icons.apps;
    }
  }
}
