// lib/pages/local_user_gate.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/common.dart';
import '../main.dart';

class LocalUserGate extends StatefulWidget {
  final SupabaseService supa;
  const LocalUserGate({super.key, required this.supa});

  @override
  State<LocalUserGate> createState() => _LocalUserGateState();
}

class _LocalUserGateState extends State<LocalUserGate> {
  late Future<List<Map<String, dynamic>>> _localUsersFuture;
  final _passwordController = TextEditingController();
  String? _selectedLocalUserId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _localUsersFuture = widget.supa.fetchLocalUsers();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    setState(() => _error = null);
    if (_selectedLocalUserId == null) {
      setState(() => _error = 'Please select a local user');
      return;
    }
    final ok = await widget.supa.verifyAndSelectLocalUser(_selectedLocalUserId!, _passwordController.text);
    if (!ok) {
      setState(() => _error = 'Invalid password');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(supa: widget.supa)));
  }

  Future<void> _continueAsAdmin() async {
    setState(() => _error = null);
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) {
      setState(() => _error = 'No authenticated account found');
      return;
    }

    final adminPassController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Authentication'),
        content: TextField(
          controller: adminPassController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Account password',
            hintText: 'Enter your account password',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      // Re-authenticate by signing in with password; keeps session for same user
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: adminPassController.text);
      // Set admin mode and save context
      await widget.supa.setAdminMode();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(supa: widget.supa)));
    } catch (e) {
      setState(() => _error = 'Invalid admin password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(context, 'Choose User'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _localUsersFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snap.data ?? [];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Who is using the app?', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  const Text('No local users yet. You can add users later in the Users page.'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final u in users)
                      ChoiceChip(
                        selected: _selectedLocalUserId == u['id'],
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.person, size: 18),
                            const SizedBox(width: 6),
                            Text(u['name'] ?? 'User'),
                          ]),
                        ),
                        onSelected: (_) => setState(() => _selectedLocalUserId = u['id'] as String),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Local user password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person_outline),
                        onPressed: _proceed,
                        label: const Text('Continue as User'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings),
                        onPressed: _continueAsAdmin,
                        label: const Text('Continue as Admin'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
