import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LocalUsersTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> localUsersFuture;
  final bool isAdminContext;
  final VoidCallback onRefresh;
  final void Function(String action, Map<String, dynamic> user) onUserAction;

  const LocalUsersTab({
    super.key,
    required this.localUsersFuture,
    required this.isAdminContext,
    required this.onRefresh,
    required this.onUserAction,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: localUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final localUsers = snapshot.data ?? [];

          if (localUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No local users yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create local users to manage family members',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: localUsers.length,
            itemBuilder: (context, index) {
              final user = localUsers[index];
              final name = (user['name'] as String?) ?? 'Unknown';
              final createdAt = DateTime.tryParse(user['created_at']?.toString() ?? '') ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text('Created: ${DateFormat('MMM dd, yyyy').format(createdAt)}'),
                  trailing: isAdminContext
                      ? PopupMenuButton<String>(
                          onSelected: (value) => onUserAction(value, user),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
