// lib/pages/user_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';
import 'package:intl/intl.dart';
import '../pages/auth_page.dart';

class UserPage extends StatefulWidget {
  static const route = '/users';
  final SupabaseService supa;
  const UserPage({required this.supa, super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _localUsersFuture;
  late Future<List<Map<String, dynamic>>> _fridgeMembersFuture;
  late Future<List<Map<String, dynamic>>> _pendingRequestsFuture;
  late Future<List<Map<String, dynamic>>> _myFridgesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _localUsersFuture = widget.supa.fetchLocalUsers();
      _fridgeMembersFuture = widget.supa.fetchFridgeMembers();
      _pendingRequestsFuture = widget.supa.fetchPendingRequests();
      _myFridgesFuture = widget.supa.fetchMyFridges();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        context,
        'User Management',
        showBackIfCanPop: true,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (index) => _tabController.animateTo(index),
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'Local Users', icon: Icon(Icons.person_add)),
                Tab(text: 'Fridge Members', icon: Icon(Icons.people)),
                Tab(text: 'Join Requests', icon: Icon(Icons.pending_actions)),
                Tab(text: 'My Fridges', icon: Icon(Icons.kitchen)),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildLocalUsersTab(),
                _buildFridgeMembersTab(),
                _buildJoinRequestsTab(),
                _buildMyFridgesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0 && _isAdminContext()
          ? FloatingActionButton(
              onPressed: () => _showCreateLocalUserDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildLocalUsersTab() {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _localUsersFuture,
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      (user['name'] as String).substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(user['name'] ?? 'Unknown'),
                  subtitle: Text('Created: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(user['created_at']))}'),
                  trailing: _isAdminContext()
                      ? PopupMenuButton<String>(
                          onSelected: (value) => _handleLocalUserAction(value, user),
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

  Widget _buildFridgeMembersTab() {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fridgeMembersFuture,
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
                    'Members will appear here when they join your fridges',
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(member['role']),
                    child: Icon(
                      _getRoleIcon(member['role']),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(member['user_name'] ?? 'Unknown User'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fridge: ${member['fridge_name'] ?? 'Unknown'}'),
                      Text('Role: ${member['role'] ?? 'user'}'),
                      Text('Joined: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(member['joined_at']))}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: _isAdminContext() && _canManageUser(member)
                      ? PopupMenuButton<String>(
                          onSelected: (value) => _handleMemberAction(value, member),
                          itemBuilder: (context) => [
                            if (member['role'] != 'admin')
                              const PopupMenuItem(value: 'promote', child: Text('Promote to Admin')),
                            if (member['role'] == 'admin')
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

  Widget _buildJoinRequestsTab() {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingRequestsFuture,
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.pending, color: Colors.white),
                  ),
                  title: Text(request['requester_name'] ?? 'Unknown User'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fridge: ${request['fridge_name'] ?? 'Unknown'}'),
                      if (request['message']?.isNotEmpty == true)
                        Text('Message: ${request['message']}'),
                      Text('Requested: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(request['created_at']))}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: _isAdminContext() && _canManageRequest(request)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _handleRequestAction('approve', request),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _handleRequestAction('reject', request),
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

  Widget _buildMyFridgesTab() {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _myFridgesFuture,
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.kitchen, color: Colors.white),
                  ),
                  title: Text(fridge['name'] ?? 'Unknown Fridge'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fridge['location']?.isNotEmpty == true)
                        Text('Location: ${fridge['location']}'),
                      Text('Role: ${fridge['role'] ?? 'user'}'),
                      Text('Created: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(fridge['created_at']))}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: _isAdminContext() && _canManageFridge(fridge)
                      ? PopupMenuButton<String>(
                          onSelected: (value) => _handleFridgeAction(value, fridge),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit Fridge')),
                            const PopupMenuItem(value: 'invite', child: Text('Invite Users')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete Fridge')),
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

  // Helper methods
  bool _isAdminContext() {
    // If a local user is active, consider them non-admin context.
    // When admin chooses "Continue as Admin", activeLocalUserId will be null.
    return widget.supa.activeLocalUserId == null;
  }

  Future<void> _logout() async {
    // Clear user context
    await widget.supa.clearUserContext();
    // Sign out from Supabase
    await Supabase.instance.client.auth.signOut();
    
    // Navigate back to auth page and clear all previous routes
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthGate(supa: widget.supa)),
        (route) => false,
      );
    }
  }
  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'user':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  bool _canManageUser(Map<String, dynamic> member) {
    // TODO: Implement based on user role and permissions
    return true; // Placeholder
  }

  bool _canManageRequest(Map<String, dynamic> request) {
    // TODO: Implement based on user role and permissions
    return true; // Placeholder
  }

  bool _canManageFridge(Map<String, dynamic> fridge) {
    // TODO: Implement based on user role and permissions
    return true; // Placeholder
  }

  void _handleLocalUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'edit':
        _showEditLocalUserDialog(context, user);
        break;
      case 'delete':
        _showDeleteLocalUserDialog(context, user);
        break;
    }
  }

  void _handleMemberAction(String action, Map<String, dynamic> member) {
    switch (action) {
      case 'promote':
        _promoteUser(member);
        break;
      case 'demote':
        _demoteUser(member);
        break;
      case 'remove':
        _removeUser(member);
        break;
    }
  }

  void _handleRequestAction(String action, Map<String, dynamic> request) {
    switch (action) {
      case 'approve':
        _approveRequest(request);
        break;
      case 'reject':
        _rejectRequest(request);
        break;
    }
  }

  void _handleFridgeAction(String action, Map<String, dynamic> fridge) {
    switch (action) {
      case 'edit':
        _showEditFridgeDialog(context, fridge);
        break;
      case 'invite':
        _showInviteUsersDialog(context, fridge);
        break;
      case 'delete':
        _showDeleteFridgeDialog(context, fridge);
        break;
    }
  }

  // Dialog methods
  void _showCreateLocalUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Local User'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'User Name',
                  hintText: 'Enter the name of the local user',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Choose a password for this local user',
                ),
                validator: (v) => (v == null || v.length < 4) ? 'Min 4 characters' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await widget.supa.createLocalUserWithPassword(
                    nameController.text.trim(),
                    passController.text,
                  );
                  Navigator.pop(context);
                  _refreshData();
                  
                  // If this was the first local user created, redirect to local user gate
                  final allUsers = await widget.supa.fetchLocalUsers();
                  if (allUsers.length == 1) {
                    // First user created, redirect to local user gate
                    if (!mounted) return;
                    Navigator.of(context).pushReplacementNamed('/local-user');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditLocalUserDialog(BuildContext context, Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name']);
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Local User'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'User Name',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await widget.supa.updateLocalUser(user['id'], nameController.text.trim());
                  if (passController.text.isNotEmpty) {
                    await widget.supa.updateLocalUserPassword(user['id'], passController.text);
                  }
                  Navigator.pop(context);
                  _refreshData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteLocalUserDialog(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Local User'),
        content: Text('Are you sure you want to delete ${user['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await widget.supa.deleteLocalUser(user['id']);
                Navigator.pop(context);
                _refreshData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Action methods
  void _promoteUser(Map<String, dynamic> member) async {
    try {
      await widget.supa.promoteUser(member['user_id'], member['fridge_id']);
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _demoteUser(Map<String, dynamic> member) async {
    try {
      await widget.supa.demoteUser(member['user_id'], member['fridge_id']);
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _removeUser(Map<String, dynamic> member) async {
    try {
      await widget.supa.removeUserFromFridge(member['user_id'], member['fridge_id']);
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _approveRequest(Map<String, dynamic> request) async {
    try {
      await widget.supa.approveJoinRequest(request['id']);
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _rejectRequest(Map<String, dynamic> request) async {
    try {
      await widget.supa.rejectJoinRequest(request['id']);
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Placeholder dialog methods
  void _showEditFridgeDialog(BuildContext context, Map<String, dynamic> fridge) {
    showCornerToast(context, message: 'Edit fridge - coming soon');
  }

  void _showInviteUsersDialog(BuildContext context, Map<String, dynamic> fridge) {
    showCornerToast(context, message: 'Invite users - coming soon');
  }

  void _showDeleteFridgeDialog(BuildContext context, Map<String, dynamic> fridge) {
    showCornerToast(context, message: 'Delete fridge - coming soon');
  }
}
