// lib/pages/auth_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../widgets/common.dart';

class AuthGate extends StatefulWidget {
  final SupabaseService supa;
  const AuthGate({Key? key, required this.supa}) : super(key: key);

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _isLogin = true;
  bool _loading = false;
  bool _navigating = false; // prevents double navigation

  late final AnimationController _logoCtrl;

  @override
  void initState() {
    super.initState();
    // small logo pop animation
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoCtrl.forward();

    // autofocus email after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_emailFocus);
    });

    // Keep auth-state listener as a safety net but guard double nav
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && !_navigating) {
        _navigating = true;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(supa: widget.supa)));
      }
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _emailController.dispose();
    _passController.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // Basic email validation
  bool _isValidEmail(String e) {
    final email = e.trim();
    final regex = RegExp(r"^[\w\.\-+%]+@[A-Za-z0-9\.\-]+\.[A-Za-z]{2,}$");
    return regex.hasMatch(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Dismiss', onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
    ));
  }

  Future<void> _showSuccessAndNavigate() async {
    // small modal with check animation
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (ctx, a1, a2) {
        return const SizedBox.shrink(); // pageBuilder not used because transitionBuilder provides content
      },
      transitionBuilder: (ctx, anim1, anim2, _) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.elasticOut);
        return Transform.scale(
          scale: curved.value,
          child: Opacity(
            opacity: anim1.value,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 8),
                      Text('Success', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_loading) return;

    final email = _emailController.text.trim();
    final pass = _passController.text;

    if (email.isEmpty || pass.isEmpty) {
      _showError('Please enter email and password.');
      return;
    }
    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        // Attempt sign-in
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: pass);

        // If user is logged in (session exists), show success then navigate.
        final current = Supabase.instance.client.auth.currentUser;
        if (current != null) {
          // Show quick success animation then navigate
          await _showSuccessAndNavigate();
          if (!_navigating && mounted) {
            _navigating = true;
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(supa: widget.supa)));
          }
        } else {
          // Fallback: auth-state listener may handle navigation; otherwise inform user
          _showError('Signed in but session not found yet. If this persists, try restarting the app.');
        }
      } else {
        // Sign up
        final res = await Supabase.instance.client.auth.signUp(email: email, password: pass);
        // If signUp created a session, navigate; else instruct user to confirm email
        final current = Supabase.instance.client.auth.currentUser;
        if (current != null) {
          await _showSuccessAndNavigate();
          if (!_navigating && mounted) {
            _navigating = true;
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(supa: widget.supa)));
          }
        } else {
          _showError('Sign up successful — please check your email to confirm your account.');
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // small combined transition used in AnimatedSwitcher
  Widget _switchTransition(Widget child, Animation<double> animation) {
    final offset = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(animation);
    return SlideTransition(position: offset, child: FadeTransition(opacity: animation, child: child));
  }

  @override
  Widget build(BuildContext context) {
    // Keep the appbar label simple: only WasteLess
    return Scaffold(
      appBar: buildGradientAppBar(context, 'WasteLess'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            height: _isLogin ? 360 : 420,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo + app title (animated)
                    Center(
                      child: ScaleTransition(
                        scale: CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco, size: 30, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('WasteLess', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subheading is removed per your request — only WasteLess is shown in header.
                    // Animated form area
                    const SizedBox(height: 4),

                    AnimatedSwitcher(duration: const Duration(milliseconds: 350), transitionBuilder: _switchTransition, child: _buildForm(key: ValueKey<bool>(_isLogin))),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () {
                        setState(() => _isLogin = !_isLogin);
                        _logoCtrl.forward(from: 0.0);
                        // move focus back to email
                        FocusScope.of(context).requestFocus(_emailFocus);
                      },
                      child: Text(_isLogin ? 'Need an account? Sign Up' : 'Have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required Key key}) {
    return Container(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            focusNode: _emailFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passFocus.requestFocus(),
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
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
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.login),
              onPressed: _loading ? null : _submit,
              label: Text(_loading ? (_isLogin ? 'Logging in...' : 'Signing up...') : (_isLogin ? 'Login' : 'Sign Up')),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
