// lib/features/users/user_page.dart
import 'package:flutter/material.dart';

import '../../pages/auth_page.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'widgets/fridge_members_tab.dart';
import 'widgets/join_requests_tab.dart';
import 'widgets/local_users_tab.dart';
import 'widgets/my_fridges_tab.dart';

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

  bool _isAdminContext() {
    return widget.supa.activeLocalUserId == null;
  }

  Future<void> _logout() async {
    await widget.supa.client.auth.signOut();
    widget.supa.clearUserContext();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthGate(supa: widget.supa)),
      (route) => false,
    );
  }

  bool _canManageUser(Map<String, dynamic> member) {
    if (member['user_id'] == widget.supa.client.auth.currentUser?.id) return false;
    return true;
  }

  bool _canManageRequest(Map<String, dynamic> request) {
    return true;
  }

  bool _canManageFridge(Map<String, dynamic> fridge) {
    return fridge['role'] == 'admin';
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
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
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                LocalUsersTab(
                  localUsersFuture: _localUsersFuture,
                  isAdminContext: _isAdminContext(),
                  onRefresh: _refreshData,
                  onUserAction: (action, user) {
                    if (action == 'edit') {
                      _showEditLocalUserDialog(context, user);
                    } else if (action == 'delete') {
                      _showDeleteLocalUserDialog(context, user);
                    }
                  },
                ),
                FridgeMembersTab(
                  fridgeMembersFuture: _fridgeMembersFuture,
                  isAdminContext: _isAdminContext(),
                  canManageUser: _canManageUser,
                  onRefresh: _refreshData,
                  onMemberAction: (action, member) {
                    if (action == 'promote') {
                      _promoteUser(member);
                    } else if (action == 'demote') {
                      _demoteUser(member);
                    } else if (action == 'remove') {
                      _removeUser(member);
                    }
                  },
                ),
                JoinRequestsTab(
                  pendingRequestsFuture: _pendingRequestsFuture,
                  isAdminContext: _isAdminContext(),
                  canManageRequest: _canManageRequest,
                  onRefresh: _refreshData,
                  onRequestAction: (action, request) {
                    if (action == 'approve') {
                      _approveRequest(request);
                    } else if (action == 'reject') {
                      _rejectRequest(request);
                    }
                  },
                ),
                MyFridgesTab(
                  myFridgesFuture: _myFridgesFuture,
                  isAdminContext: _isAdminContext(),
                  canManageFridge: _canManageFridge,
                  onRefresh: _refreshData,
                  onFridgeAction: (action, fridge) {
                    if (action == 'edit') {
                      _showEditFridgeDialog(context, fridge);
                    } else if (action == 'invite') {
                      _showInviteUsersDialog(context, fridge);
                    } else if (action == 'delete') {
                      _showDeleteFridgeDialog(context, fridge);
                    }
                  },
                ),
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

  void _showCreateLocalUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final passController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
                  hintText: 'e.g., Mom, Dad, Child',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password/PIN',
                  hintText: 'Enter password or PIN',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
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
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _refreshData();

                  final allUsers = await widget.supa.fetchLocalUsers();
                  if (allUsers.length == 1) {
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed('/local-user');
                  }
                } catch (e) {
                  if (!context.mounted) return;
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
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Local User'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'User Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
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
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (!context.mounted) return;
                  _refreshData();
                } catch (e) {
                  if (!context.mounted) return;
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
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Local User'),
        content: Text('Are you sure you want to delete ${user['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await widget.supa.deleteLocalUser(user['id']);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (!context.mounted) return;
                _refreshData();
              } catch (e) {
                if (!context.mounted) return;
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

  void _promoteUser(Map<String, dynamic> member) async {
    try {
      await widget.supa.promoteUser(member['user_id'], member['fridge_id']);
      if (!mounted) return;
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _demoteUser(Map<String, dynamic> member) async {
    try {
      await widget.supa.demoteUser(member['user_id'], member['fridge_id']);
      if (!mounted) return;
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _removeUser(Map<String, dynamic> member) async {
    try {
      await widget.supa.removeUserFromFridge(member['user_id'], member['fridge_id']);
      if (!mounted) return;
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _approveRequest(Map<String, dynamic> request) async {
    try {
      await widget.supa.approveJoinRequest(request['id']);
      if (!mounted) return;
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _rejectRequest(Map<String, dynamic> request) async {
    try {
      await widget.supa.rejectJoinRequest(request['id']);
      if (!mounted) return;
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showEditFridgeDialog(BuildContext context, Map<String, dynamic> fridge) {
    showCornerToast(context, message: 'Editing fridge coming soon');
  }

  void _showInviteUsersDialog(BuildContext context, Map<String, dynamic> fridge) async {
    final code = await widget.supa.regenerateFridgeCode(fridge['id']);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with members to let them join your fridge:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code ?? 'CODE',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFridgeDialog(BuildContext context, Map<String, dynamic> fridge) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Fridge'),
        content: Text('Are you sure you want to delete ${fridge['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final ok = await widget.supa.deleteFridge(fridge['id']);
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                if (!context.mounted) return;
                if (ok) {
                  showCornerToast(context, message: 'Deleted fridge ${fridge['name']}');
                  _refreshData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete fridge')),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
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
}
