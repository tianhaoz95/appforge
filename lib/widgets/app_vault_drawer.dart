import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/micro_app_repository.dart';
import '../repositories/conversation_repository.dart';

class AppVaultDrawer extends StatefulWidget {
  final Function(Map<String, dynamic> app)? onAppSelected;
  final Function(String conversationId, String title)? onConversationSelected;

  const AppVaultDrawer({super.key, this.onAppSelected, this.onConversationSelected});

  @override
  State<AppVaultDrawer> createState() => _AppVaultDrawerState();
}

class _AppVaultDrawerState extends State<AppVaultDrawer> {
  late Future<List<Map<String, dynamic>>> _appsFuture;
  late Future<List<Map<String, dynamic>>> _convsFuture;
  static const userId = 'local-user';

  @override
  void initState() {
    super.initState();
    // In order to use Provider.of in initState, we'd need listen: false,
    // but the future should be initialized using the repositories.
    // However, build() is where we have access to context easily.
    // We can initialize them in didChangeDependencies.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshApps();
    _refreshConvs();
  }

  void _refreshApps() {
    final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
    setState(() {
      _appsFuture = appRepository.getAppsForOwner(userId);
    });
  }

  void _refreshConvs() {
    final convRepository = Provider.of<ConversationRepository>(context, listen: false);
    setState(() {
      _convsFuture = convRepository.getConversations();
    });
  }

  Future<void> _confirmDelete(Map<String, dynamic> app) async {
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

    if (shouldDelete == true) {
      final appRepository = Provider.of<MicroAppRepository>(context, listen: false);
      await appRepository.deleteApp(app['appId']);
      _refreshApps();
    }
  }

  Future<void> _confirmDeleteConversation(Map<String, dynamic> conv) async {
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

    if (shouldDelete == true) {
      final convRepository = Provider.of<ConversationRepository>(context, listen: false);
      await convRepository.deleteConversation(conv['conversationId']);
      _refreshConvs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey[800]!, Colors.blueGrey[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'brand/logo.png',
                        height: 32,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.auto_awesome_motion, size: 32, color: Colors.indigo),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'AppVault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Local Mode (Offline)',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const Text(
                  'Your forges are saved locally.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const ListTile(
            title: Text(
              'Recent Chats',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
              return Column(
                children: convs.take(5).map((conv) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.chat_bubble_outline, size: 20),
                  title: Text(conv['title'] ?? 'Untitled Chat', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    widget.onConversationSelected?.call(conv['conversationId'], conv['title'] ?? 'Untitled Chat');
                    Navigator.pop(context);
                  },
                  onLongPress: () => _confirmDeleteConversation(conv),
                )).toList(),
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
                children: apps.map((app) => ListTile(
                  leading: Icon(_getIcon(app['icon'])),
                  title: Text(app['name'] ?? 'Unnamed App'),
                  subtitle: Text('v${app['version']}'),
                  onTap: () {
                    widget.onAppSelected?.call(app);
                    Navigator.pop(context);
                  },
                  onLongPress: () => _confirmDelete(app),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
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
