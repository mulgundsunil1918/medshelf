import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import 'specialty_onboarding_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kTeal     = Color(0xFF006B74);
const _kTealDark = Color(0xFF003D45);

// ─── AuthScreen ───────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    await OnboardingService.instance.setHasSeenAuth();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SpecialtyOnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Teal gradient background (top ~45%) ────────────────────────────
          Container(
            height: size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kTeal, _kTealDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ── White card bottom ──────────────────────────────────────────────
          Positioned(
            top: size.height * 0.40,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ),

          // ── Full scrollable content ────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // TOP: icon + subtitle
                SizedBox(
                  height: size.height * 0.34,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/icon/app_icon.jpg',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your personal medical library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // BOTTOM: white card content
                Expanded(
                  child: Column(
                    children: [
                      // Tab bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: _kTeal,
                          indicatorColor: _kTeal,
                          indicatorWeight: 2.5,
                          unselectedLabelColor: Colors.black45,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          tabs: const [
                            Tab(text: 'Sign Up'),
                            Tab(text: 'Sign In'),
                          ],
                        ),
                      ),

                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _SignUpTab(onDone: _proceed),
                            _SignInTab(onDone: _proceed),
                          ],
                        ),
                      ),

                      // Skip + caption
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          4,
                          24,
                          MediaQuery.of(context).padding.bottom + 16,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _proceed,
                                child: const Text('Skip for now'),
                              ),
                            ),
                            const Text(
                              'Sign up for a personalised experience and to help improve MedShelf',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sign-up tab ──────────────────────────────────────────────────────────────

class _SignUpTab extends StatefulWidget {
  const _SignUpTab({required this.onDone});

  final Future<void> Function() onDone;

  @override
  State<_SignUpTab> createState() => _SignUpTabState();
}

class _SignUpTabState extends State<_SignUpTab> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user?.uid)
          .set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      });
      await widget.onDone();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mapAuthError(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InputField(
            controller: _nameCtrl,
            label: 'Name',
            icon: Icons.person_outline_rounded,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _InputField(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: _passwordCtrl,
            obscure: _obscure,
            onToggle: () => setState(() => _obscure = !_obscure),
            helperText: 'Min 6 characters',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          _SubmitButton(
            label: 'Create Account',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ─── Sign-in tab ──────────────────────────────────────────────────────────────

class _SignInTab extends StatefulWidget {
  const _SignInTab({required this.onDone});

  final Future<void> Function() onDone;

  @override
  State<_SignInTab> createState() => _SignInTabState();
}

class _SignInTabState extends State<_SignInTab> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await widget.onDone();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mapAuthError(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InputField(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: _passwordCtrl,
            obscure: _obscure,
            onToggle: () => setState(() => _obscure = !_obscure),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          _SubmitButton(
            label: 'Sign In',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.type = TextInputType.text,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType type;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: type,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.helperText,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        helperText: helperText,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _kTeal,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(
              label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Auth error mapping ───────────────────────────────────────────────────────

String _mapAuthError(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'wrong-password':
      return 'Incorrect password. Please try again.';
    case 'user-not-found':
      return 'No account found with this email.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'invalid-credential':
      return 'Incorrect email or password. Please try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Please check your connection.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
