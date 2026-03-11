import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/micro_app_repository.dart';

class AppVaultDrawer extends StatelessWidget {
  final Function(Map<String, dynamic> app)? onAppSelected;

  const AppVaultDrawer({super.key, this.onAppSelected});

  @override
  Widget build(BuildContext context) {
    final repository = Provider.of<MicroAppRepository>(context);
    const userId = 'local-user';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blueGrey,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AppVault',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Local Mode',
                  style: TextStyle(color: Colors.white70),
                ),
                const Text(
                  'No Firebase Connection',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
          // TODO: Add list of recent chats
          const Divider(),
          const ListTile(
            title: Text(
              'Forged Apps',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: repository.getAppsForOwner(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
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
                    onAppSelected?.call(app);
                    Navigator.pop(context);
                  },
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
