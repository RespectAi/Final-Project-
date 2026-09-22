import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class JoinRequestsTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> pendingRequestsFuture;
  final bool isAdminContext;
  final bool Function(Map<String, dynamic> request) canManageRequest;
  final VoidCallback onRefresh;
  final void Function(String action, Map<String, dynamic> request) onRequestAction;

  const JoinRequestsTab({
    super.key,
    required this.pendingRequestsFuture,
    required this.isAdminContext,
    required this.canManageRequest,
    required this.onRefresh,
    required this.onRequestAction,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: pendingRequestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All join requests have been processed',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final requesterName = request['requester_name'] ?? 'Unknown User';
              final fridgeName = request['fridge_name'] ?? 'Unknown';
              final message = request['message']?.toString();
              final createdAt = DateTime.tryParse(request['created_at']?.toString() ?? '') ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.pending, color: Colors.white),
                  ),
                  title: Text(requesterName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fridge: $fridgeName'),
                      if (message != null && message.isNotEmpty)
                        Text('Message: $message'),
                      Text('Requested: ${DateFormat('MMM dd, yyyy').format(createdAt)}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: isAdminContext && canManageRequest(request)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => onRequestAction('approve', request),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => onRequestAction('reject', request),
                            ),
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
