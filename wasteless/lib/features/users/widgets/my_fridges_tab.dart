import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyFridgesTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> myFridgesFuture;
  final bool isAdminContext;
  final bool Function(Map<String, dynamic> fridge) canManageFridge;
  final VoidCallback onRefresh;
  final void Function(String action, Map<String, dynamic> fridge) onFridgeAction;

  const MyFridgesTab({
    super.key,
    required this.myFridgesFuture,
    required this.isAdminContext,
    required this.canManageFridge,
    required this.onRefresh,
    required this.onFridgeAction,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: myFridgesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final fridges = snapshot.data ?? [];

          if (fridges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.kitchen_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No fridges yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a fridge to start managing your inventory',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fridges.length,
            itemBuilder: (context, index) {
              final fridge = fridges[index];
              final fridgeName = fridge['name'] ?? 'Unknown Fridge';
              final role = fridge['role'] ?? 'user';
              final location = fridge['location'] as String?;
              final createdAt = DateTime.tryParse(fridge['created_at']?.toString() ?? '') ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.kitchen, color: Colors.white),
                  ),
                  title: Text(fridgeName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (location != null && location.isNotEmpty)
                        Text('Location: $location'),
                      Text('Role: $role'),
                      Text('Created: ${DateFormat('MMM dd, yyyy').format(createdAt)}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: isAdminContext && canManageFridge(fridge)
                      ? PopupMenuButton<String>(
                          onSelected: (value) => onFridgeAction(value, fridge),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit Fridge')),
                            PopupMenuItem(value: 'invite', child: Text('Invite Users')),
                            PopupMenuItem(value: 'delete', child: Text('Delete Fridge')),
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
