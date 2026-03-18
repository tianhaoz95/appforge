import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isSignIn = true;
  bool _rememberMe = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isSignIn) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (_nameCtrl.text.trim().isNotEmpty) {
          await cred.user?.updateDisplayName(_nameCtrl.text.trim());
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Auth error type: ${e.runtimeType}, message: $e');
      setState(() => _error = e is FirebaseAuthException ? (e.message ?? e.code) : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } catch (e) {
      setState(() => _error = e is FirebaseAuthException ? e.message : e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/brand/logo.png', height: 56),
                      const SizedBox(height: 12),
                      Text('MicroForge', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_isSignIn ? 'Sign in to your account' : 'Create a new account',
                          style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                      const SizedBox(height: 28),
                      if (!_isSignIn)
                        _field(_nameCtrl, 'Display Name', Icons.person_outline, required: false),
                      _field(_emailCtrl, 'Email', Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
                      _field(_passwordCtrl, 'Password', Icons.lock_outline,
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null),
                      if (_isSignIn) ...[
                        Row(
                          children: [
                            Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? false)),
                            const Text('Remember me'),
                            const Spacer(),
                            TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
                          ],
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_isSignIn ? 'Sign In' : 'Sign Up'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() { _isSignIn = !_isSignIn; _error = null; }),
                        child: Text(_isSignIn
                            ? "Don't have an account? Sign up"
                            : 'Already have an account? Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: required
            ? (validator ?? (v) => (v == null || v.isEmpty) ? 'Required' : null)
            : validator,
      ),
    );
  }
}
