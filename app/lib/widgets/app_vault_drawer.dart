import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/micro_app_repository.dart';
import '../repositories/conversation_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'dart:io';
import 'dart:convert';
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
  bool _isOlderChatsExpanded = false;
  bool _isOlderAppsExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: isDark ? Colors.black : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  const GradientIcon(icon: Icons.auto_awesome_motion, size: 24),
                  const SizedBox(width: 12),
                  const GradientText(
                    'Vault',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Consumer2<AuthProvider, SettingsProvider>(
                    builder: (context, auth, settings, _) {
                      return CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        backgroundImage: settings.localAvatarPath.isNotEmpty
                            ? FileImage(File(settings.localAvatarPath))
                            : null,
                        child: settings.localAvatarPath.isEmpty
                            ? Text(
                                auth.user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // CHATS SECTION
                  _buildMinimalSectionHeader(
                    'CHATS', 
                    _isChatSelectionMode, 
                    _selectedConversationIds.length, 
                    _convsFuture,
                    'conversationId',
                    (allIds) => setState(() {
                      if (_selectedConversationIds.length == allIds.length) {
                        _selectedConversationIds.clear();
                      } else {
                        _selectedConversationIds.addAll(allIds);
                      }
                    }),
                    () => setState(() {
                      _isChatSelectionMode = false;
                      _selectedConversationIds.clear();
                    }), 
                    () => _confirmBulkDelete(context, 'chats')
                  ),
                  
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _convsFuture,
                    builder: (context, snapshot) {
                      final convs = snapshot.data ?? [];
                      if (convs.isEmpty && snapshot.connectionState == ConnectionState.done) {
                        return _buildEmptyState('No history');
                      }
                      
                      final recent = convs.take(5).toList();
                      final older = convs.skip(5).toList();

                      return Column(
                        children: [
                          ...recent.map((c) => _buildMinimalConvTile(c)),
                          if (older.isNotEmpty)
                            _buildCollapsibleSection(
                              'Older Chats', 
                              older.map((c) => _buildMinimalConvTile(c)).toList(),
                              _isOlderChatsExpanded || _isChatSelectionMode,
                              (val) => setState(() => _isOlderChatsExpanded = val),
                            ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // APPS SECTION
                  _buildMinimalSectionHeader(
                    'APPS', 
                    _isAppSelectionMode, 
                    _selectedAppIds.length, 
                    _appsFuture,
                    'appId',
                    (allIds) => setState(() {
                      if (_selectedAppIds.length == allIds.length) {
                        _selectedAppIds.clear();
                      } else {
                        _selectedAppIds.addAll(allIds);
                      }
                    }),
                    () => setState(() {
                      _isAppSelectionMode = false;
                      _selectedAppIds.clear();
                    }), 
                    () => _confirmBulkDelete(context, 'apps')
                  ),
                  
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _appsFuture,
                    builder: (context, snapshot) {
                      final apps = snapshot.data ?? [];
                      if (apps.isEmpty && snapshot.connectionState == ConnectionState.done) {
                        return _buildEmptyState('No apps forged');
                      }

                      final recent = apps.take(10).toList();
                      final older = apps.skip(10).toList();

                      return Column(
                        children: [
                          ...recent.map((a) => _buildMinimalAppTile(a)),
                          if (older.isNotEmpty)
                            _buildCollapsibleSection(
                              'More Apps', 
                              older.map((a) => _buildMinimalAppTile(a)).toList(),
                              _isOlderAppsExpanded || _isAppSelectionMode,
                              (val) => setState(() => _isOlderAppsExpanded = val),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection(String title, List<Widget> children, bool expanded, Function(bool) onToggle) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        initiallyExpanded: expanded,
        onExpansionChanged: onToggle,
        visualDensity: VisualDensity.compact,
        title: Text(
          '$title (${children.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        children: children,
      ),
    );
  }

  Widget _buildMinimalSectionHeader(
    String title, 
    bool isSelection, 
    int count, 
    Future<List<Map<String, dynamic>>>? itemsFuture,
    String idKey,
    Function(Set<String>) onSelectAll,
    VoidCallback onCancel, 
    VoidCallback onDelete
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Text(
            isSelection ? '$count SELECTED' : title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const Spacer(),
          if (isSelection) ...[
            FutureBuilder<List<Map<String, dynamic>>>(
              future: itemsFuture,
              builder: (context, snapshot) {
                final allIds = (snapshot.data ?? []).map((i) => i[idKey] as String).toSet();
                final isAllSelected = count == allIds.length && allIds.isNotEmpty;
                return IconButton(
                  icon: Icon(isAllSelected ? Icons.deselect_outlined : Icons.select_all_rounded, size: 16),
                  onPressed: () => onSelectAll(allIds),
                  visualDensity: VisualDensity.compact,
                  tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                );
              }
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              onPressed: count == 0 ? null : onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimalConvTile(Map<String, dynamic> conv) {
    final id = conv['conversationId'] as String;
    final isSelected = _selectedConversationIds.contains(id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: isSelected,
      selectedTileColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
      leading: _isChatSelectionMode 
        ? _buildTinyCheckbox(isSelected)
        : Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
      title: Text(
        conv['title'] ?? 'Untitled',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: isSelected ? 1.0 : 0.8),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _isChatSelectionMode ? null : _buildItemMenu(conv, 'chat'),
      onTap: () {
        if (_isChatSelectionMode) {
          setState(() => isSelected ? _selectedConversationIds.remove(id) : _selectedConversationIds.add(id));
        } else {
          widget.onConversationSelected?.call(id, conv['title'] ?? 'Untitled');
          Navigator.pop(context);
        }
      },
      onLongPress: () {
        if (!_isChatSelectionMode) {
          setState(() {
            _isChatSelectionMode = true;
            _selectedConversationIds.add(id);
          });
        }
      },
    );
  }

  Widget _buildMinimalAppTile(Map<String, dynamic> app) {
    final id = app['appId'] as String;
    final isSelected = _selectedAppIds.contains(id);
    final isPinned = (app['is_pinned'] ?? 0) == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: isSelected,
      selectedTileColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
      leading: _isAppSelectionMode 
        ? _buildTinyCheckbox(isSelected)
        : _buildAppIcon(app['icon'], isPinned),
      title: Text(
        app['name'] ?? 'Unnamed',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _isAppSelectionMode ? null : _buildItemMenu(app, 'app'),
      onTap: () {
        if (_isAppSelectionMode) {
          setState(() => isSelected ? _selectedAppIds.remove(id) : _selectedAppIds.add(id));
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
    );
  }

  Widget _buildItemMenu(Map<String, dynamic> item, String type) {
    final isPinned = (item['is_pinned'] ?? 0) == 1;
    final id = type == 'chat' ? item['conversationId'] : item['appId'];

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
      onSelected: (value) async {
        if (type == 'app') {
          final repo = Provider.of<MicroAppRepository>(context, listen: false);
          if (value == 'pin') await repo.pinApp(id, !isPinned);
          if (value == 'rename') await _showRenameDialog(context, item);
          if (value == 'delete') await _confirmDelete(context, item);
        } else {
          final repo = Provider.of<ConversationRepository>(context, listen: false);
          if (value == 'delete') await _confirmDeleteConversation(context, item);
        }
      },
      itemBuilder: (context) => [
        if (type == 'app') ...[
          PopupMenuItem(
            value: 'pin',
            child: ListTile(
              leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 16),
              title: Text(isPinned ? 'Unpin' : 'Pin', style: const TextStyle(fontSize: 13)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined, size: 16),
              title: Text('Rename', style: TextStyle(fontSize: 13)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red, size: 16),
            title: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildAppIcon(String? icon, bool isPinned) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _getIconWidget(icon, size: 14),
          if (isPinned)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  gradient: AppTheme.vibrantGradient,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getIconWidget(String? icon, {double size = 16}) {
    if (icon == null || icon.isEmpty) return Icon(Icons.layers_outlined, size: size);
    if (icon.length > 2) {
       switch (icon) {
        case 'rocket': return Icon(Icons.rocket_launch_outlined, size: size);
        case 'speed': return Icon(Icons.speed_outlined, size: size);
        case 'bolt': return Icon(Icons.bolt_outlined, size: size);
        default: return Icon(Icons.layers_outlined, size: size);
      }
    }
    return Text(icon, style: TextStyle(fontSize: size));
  }

  Widget _buildTinyCheckbox(bool checked) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? Colors.transparent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          width: 1.5,
        ),
        gradient: checked ? AppTheme.vibrantGradient : null,
      ),
      child: checked ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        msg,
        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontStyle: FontStyle.italic),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, Map<String, dynamic> app) async {
    final controller = TextEditingController(text: app['name']);
    final bool? shouldRename = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'App Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldRename == true && controller.text.trim().isNotEmpty && context.mounted) {
      final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
      await appRepository.renameApp(app['appId'], controller.text.trim());
    }
  }

  Future<void> _confirmBulkDelete(BuildContext context, String type) async {
    final count = type == 'chats' ? _selectedConversationIds.length : _selectedAppIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count items?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: const Text('This action cannot be undone.', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      if (type == 'chats') {
        await Provider.of<ConversationRepository>(context, listen: false).deleteConversations(_selectedConversationIds.toList());
        setState(() { _isChatSelectionMode = false; _selectedConversationIds.clear(); });
      } else {
        await Provider.of<MicroAppRepository>(context, listen: false).deleteApps(_selectedAppIds.toList());
        setState(() { _isAppSelectionMode = false; _selectedAppIds.clear(); });
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> app) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete App?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Text('Delete "${app['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && context.mounted) {
      await Provider.of<MicroAppRepository>(context, listen: false).deleteApp(app['appId']);
    }
  }

  Future<void> _confirmDeleteConversation(BuildContext context, Map<String, dynamic> conv) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Text('Delete "${conv['title'] ?? 'Untitled'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && context.mounted) {
      await Provider.of<ConversationRepository>(context, listen: false).deleteConversation(conv['conversationId']);
    }
  }
}
