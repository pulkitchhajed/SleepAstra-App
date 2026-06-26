import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../providers/onboarding_provider.dart';
import '../../../screens/main_nav_screen.dart';
import 'email_step_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;

class SignupStepScreen extends StatefulWidget {
  const SignupStepScreen({super.key});

  @override
  State<SignupStepScreen> createState() => _SignupStepScreenState();
}

class _SignupStepScreenState extends State<SignupStepScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _showPw = false;
  bool _isLoading = false;
  bool _isLogin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // If Firebase already has an authenticated (non-anonymous) session,
    // skip this screen and route based on the existing profile.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExistingSession());
  }

  Future<void> _checkExistingSession() async {
    final currentUser = fba.FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.isAnonymous) return;

    // Already signed in — load profile and decide where to go.
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final provider = context.read<OnboardingProvider>();
    await provider.loadProfile(auth.uid ?? currentUser.uid, userEmail: currentUser.email);
    if (!mounted) return;

    if (provider.isComplete) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (r) => false,
      );
    } else {
      // Profile exists but onboarding is incomplete — continue from where they left off.
      _proceedToQuestions();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final email = _emailCtrl.text.trim();
      final password = _pwCtrl.text.trim();
      
      final user = _isLogin 
          ? await auth.signInWithEmailAndPassword(email, password)
          : await auth.signUpWithEmailAndPassword(email, password);
          
      if (user == null) {
        setState(() => _errorMessage = 'Authentication failed. Please check your credentials.');
        return;
      }
      
      if (!mounted) return;
      final effectiveUid = user.uid;
      final provider = context.read<OnboardingProvider>();
      await provider.loadProfile(effectiveUid, userEmail: email);
      if (!mounted) return;
      // Force saving the email to the profile if they just signed up
      if (!_isLogin && (provider.profile.email == null || provider.profile.email!.isEmpty)) {
        provider.saveProfile(effectiveUid); // the email is already in the auth state and was synced in loadProfile
      }
      if (provider.isComplete) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavScreen()), (r) => false);
      } else {
        _proceedToQuestions();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proceedToQuestions() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailStepScreen()));
  }

  Future<void> _signInWithGoogle({bool forceAccountPicker = false}) async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final user = await auth.signInWithGoogle(forceAccountPicker: forceAccountPicker);
      if (!mounted) return;
      final effectiveUid = user?.uid ?? await FirestoreService.deviceUid;
      if (!mounted) return;
      final provider = context.read<OnboardingProvider>();
      await provider.loadProfile(effectiveUid, userEmail: user?.email);
      if (!mounted) return;
      if (provider.isComplete) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavScreen()), (r) => false);
      } else {
        _proceedToQuestions();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailCtrl.text;
    final password = _pwCtrl.text;
    final valid = email.contains('@') && password.length >= 6;

    final isLight = context.watch<ThemeProvider>().isDarkMode == false;
    final bg          = isLight ? AppTheme.backgroundLight    : AppTheme.background;
    final surface     = isLight ? AppTheme.surfaceLight       : AppTheme.surface;
    final textPrimary = isLight ? AppTheme.textPrimaryLight   : AppTheme.textPrimary;
    final textSec     = isLight ? AppTheme.textSecondaryLight : AppTheme.textSecondary;
    final border      = isLight ? AppTheme.cardBorderLight    : AppTheme.cardBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textSec),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepIndicator(1, 13, border),
              const SizedBox(height: 32),
              Text(_isLogin ? '👋' : '🔐', style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(_isLogin ? 'Welcome Back' : 'Create Account',
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 8),
              Text(_isLogin ? 'Sign in to access your sleep data.' : 'Secure your sleep data and sync across devices.',
                  style: TextStyle(color: textSec, fontSize: 16)),
              const SizedBox(height: 40),

              // ── Google Sign-In ──────────────────────────────────────
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo))
              else ...[
                SizedBox(
                  width: double.infinity, height: 54,
                  child: OutlinedButton(
                    onPressed: () => _signInWithGoogle(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                        SizedBox(width: 12),
                        Text('Continue with Google',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: Divider(color: border.withValues(alpha: 0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: TextStyle(color: textSec.withValues(alpha: 0.5), fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: border.withValues(alpha: 0.5))),
                ]),
                const SizedBox(height: 24),
              ],

              // ── Email / Password ────────────────────────────────────
              _label('EMAIL', textPrimary),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textPrimary),
                decoration: _inputDeco('you@example.com', surface, textSec, border),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _label('PASSWORD', textPrimary),
              TextField(
                controller: _pwCtrl,
                obscureText: !_showPw,
                style: TextStyle(color: textPrimary),
                decoration: _inputDeco('Min 6 characters', surface, textSec, border).copyWith(
                  suffixIcon: IconButton(
                    icon: Text(_showPw ? '🙈' : '👁️', style: const TextStyle(fontSize: 20)),
                    onPressed: () => setState(() => _showPw = !_showPw),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (password.isNotEmpty && !_isLogin) ...[
                const SizedBox(height: 10),
                _passwordStrengthIndicator(password.length),
              ],
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: valid ? _submitEmailAuth : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    disabledBackgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_isLogin ? 'Sign In →' : 'Create Account →',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                      child: Text.rich(
                        TextSpan(
                          text: _isLogin ? 'Don\'t have an account? ' : 'Already have an account? ',
                          style: TextStyle(color: textSec, fontSize: 13),
                          children: [
                            TextSpan(
                              text: _isLogin ? 'Sign Up' : 'Sign In',
                              style: const TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _signInWithGoogle(forceAccountPicker: true),
                      child: Text(
                        'Use a different account →',
                        style: TextStyle(color: textSec, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordStrengthIndicator(int length) {
    return Row(
      children: List.generate(4, (i) {
        final step = i + 1;
        Color color = AppTheme.primaryIndigo.withValues(alpha: 0.15);
        if (length >= step * 3) {
          if (step <= 2) { color = const Color(0xFFF97316); }
          else if (step <= 3) { color = const Color(0xFF6366F1); }
          else { color = const Color(0xFF34D399); }
        }
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
        );
      }),
    );
  }

  Widget _label(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(
        color: AppTheme.primaryIndigo, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
  );

  InputDecoration _inputDeco(String hint, Color surface, Color textSec, Color border) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: textSec),
    filled: true,
    fillColor: surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 1.5)),
  );

  Widget _stepIndicator(int current, int total, Color border) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: Container(
            height: 4, margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i < current ? AppTheme.primaryIndigo : border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
