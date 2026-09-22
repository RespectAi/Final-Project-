import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FridgeMembersTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> fridgeMembersFuture;
  final bool isAdminContext;
  final bool Function(Map<String, dynamic> member) canManageUser;
  final VoidCallback onRefresh;
  final void Function(String action, Map<String, dynamic> member) onMemberAction;

  const FridgeMembersTab({
    super.key,
    required this.fridgeMembersFuture,
    required this.isAdminContext,
    required this.canManageUser,
    required this.onRefresh,
    required this.onMemberAction,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: fridgeMembersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No fridge members yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Members will appear here once they join your fridges',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final userName = member['user_name'] ?? 'Unknown Member';
              final role = member['role'] ?? 'user';
              final fridgeName = member['fridge_name'] ?? 'Unknown';
              final joinedAt = DateTime.tryParse(member['joined_at']?.toString() ?? '') ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: role == 'admin' ? Colors.orange : Theme.of(context).primaryColor,
                    child: Text(
                      userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(userName)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: role == 'admin' ? Colors.orange.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: role == 'admin' ? Colors.orange[800] : Colors.green[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fridge: $fridgeName'),
                      Text('Joined: ${DateFormat('MMM dd, yyyy').format(joinedAt)}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: isAdminContext && canManageUser(member)
                      ? PopupMenuButton<String>(
                          onSelected: (value) => onMemberAction(value, member),
                          itemBuilder: (context) => [
                            if (role != 'admin')
                              const PopupMenuItem(value: 'promote', child: Text('Promote to Admin')),
                            if (role == 'admin')
                              const PopupMenuItem(value: 'demote', child: Text('Demote to User')),
                            const PopupMenuItem(value: 'remove', child: Text('Remove from Fridge')),
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
