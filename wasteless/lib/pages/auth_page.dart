// lib/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../widgets/common.dart';
import '../pages/local_user_gate.dart';
import 'dart:async';

class AuthGate extends StatefulWidget {
  final SupabaseService supa;
  const AuthGate({super.key, required this.supa});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  bool _isLogin = true;
  String? _error;
  bool _loading = false;
  bool _checkingSession = true;
  bool _isAuthenticated = false;
  bool _needsLocalUserPicker = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      await _resolveUserContext();
    } else {
      if (mounted) {
        setState(() {
          _checkingSession = false;
          _isAuthenticated = false;
        });
      }
    }

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        if (!_isAuthenticated) {
          await _resolveUserContext();
        }
      } else {
        if (mounted) {
          setState(() {
            _checkingSession = false;
            _isAuthenticated = false;
            _needsLocalUserPicker = false;
          });
          // Return to root if logged out
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      }
    });
  }

  Future<void> _resolveUserContext() async {
    try {
      final hasLocalUsers = await widget.supa.hasLocalUsers();
      if (hasLocalUsers) {
        await widget.supa.loadSavedUserContext();
        if (!mounted) return;
        final needsPicker = !widget.supa.isAdminMode && widget.supa.activeLocalUserId == null;
        setState(() {
          _checkingSession = false;
          _isAuthenticated = true;
          _needsLocalUserPicker = needsPicker;
        });
      } else {
        await widget.supa.setAdminMode();
        if (!mounted) return;
        setState(() {
          _checkingSession = false;
          _isAuthenticated = true;
          _needsLocalUserPicker = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _resolveUserContext: $e');
      if (mounted) {
        setState(() {
          _checkingSession = false;
          _isAuthenticated = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
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
        final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);
        if (res.session != null) {
          await _resolveUserContext();
        }
      } else {
        final res = await Supabase.instance.client.auth.signUp(email: email, password: pass);
        if (res.session != null) {
          await _resolveUserContext();
        } else {
          if (mounted) {
            setState(() {
              _error = 'Check your email to confirm your account before logging in.';
            });
          }
        }
      }
    } on AuthException catch (ae) {
      if (mounted) setState(() => _error = ae.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGradientStart, kGradientEnd]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kGradientStart.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 24),
              const Text(
                'WasteLess',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      if (_needsLocalUserPicker) {
        return LocalUserGate(
          supa: widget.supa,
          onUserSelected: () {
            setState(() {
              _needsLocalUserPicker = false;
            });
          },
        );
      }
      return HomePage(supa: widget.supa);
    }

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
                  if (_isLogin)
                    TextButton(
                      onPressed: () async {
                        final email = _emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Enter your email first")),
                          );
                          return;
                        }
                        try {
                          await widget.supa.sendPasswordReset(email);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Password reset link sent!")),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                      child: const Text("Forgot password?"),
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
