// lib/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../widgets/common.dart';
// Add the import for LocalUserGate if it exists in another file
import '../pages/local_user_gate.dart';

class AuthGate extends StatefulWidget {
  final SupabaseService supa;
  const AuthGate({super. key, required this.supa});

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  bool _isLogin = true;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        // Check if account has local users
        final hasLocalUsers = await widget.supa.hasLocalUsers();
        if (hasLocalUsers) {
          // Load saved user context first
          await widget.supa.loadSavedUserContext();
          
          // If user was previously logged in as admin or local user, go directly to dashboard
          if (widget.supa.isAdminMode || widget.supa.activeLocalUserId != null) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(supa: widget.supa)));
          } else {
            // Show local user picker
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LocalUserGate(supa: widget.supa)));
          }
        } else {
          // No local users, go directly to dashboard as admin
          await widget.supa.setAdminMode();
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(supa: widget.supa)));
        }
      } else {
        // User signed out, stay on auth page
        // The auth page will be shown by default when session is null
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final email = _emailController.text.trim();
    final pass = _passController.text;
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
      } else {
        await Supabase.instance.client.auth.signUp(email: email, password: pass);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(context, _isLogin ? 'WasteLess — Login' : 'WasteLess — Sign Up'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin ? 'Welcome back' : 'Create your account',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passFocus.requestFocus(),
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passController,
                    focusNode: _passFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _loading ? null : _submit(),
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      onPressed: _loading ? null : _submit,
                      label: _loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                          : Text(_isLogin ? 'Login' : 'Sign Up'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Need an account? Sign Up' : 'Have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
