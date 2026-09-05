import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _emailExpandCtrl;

  late final Animation<double> _fadeHeader;
  late final Animation<Offset> _slideHeader;
  late final Animation<double> _fadeGoogleBtn;
  late final Animation<Offset> _slideGoogleBtn;
  late final Animation<double> _fadeEmailBtn;
  late final Animation<Offset> _slideEmailBtn;
  late final Animation<double> _fadeFooter;
  late final Animation<Offset> _slideFooter;

  bool _emailExpanded = false;
  bool _isSignIn = true;

  final _siEmailCtrl = TextEditingController();
  final _siPwCtrl = TextEditingController();
  bool _siShowPw = false;
  bool _siLoading = false;
  String? _siError;

  final _suEmailCtrl = TextEditingController();
  final _suPwCtrl = TextEditingController();
  final _suConfirmPwCtrl = TextEditingController();
  bool _suShowPw = false;
  bool _suShowConfirm = false;
  bool _suLoading = false;
  String? _suError;

  bool _googleLoading = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _emailExpandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Staggered Animations to match framer-motion staggerChildren
    _fadeHeader = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.15, 0.6, curve: Curves.easeOut)),
    );
    _slideHeader = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.15, 0.6, curve: Curves.easeOut)),
    );

    _fadeGoogleBtn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.25, 0.75, curve: Curves.easeOut)),
    );
    _slideGoogleBtn = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.25, 0.75, curve: Curves.easeOut)),
    );

    _fadeEmailBtn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.35, 0.85, curve: Curves.easeOut)),
    );
    _slideEmailBtn = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.35, 0.85, curve: Curves.easeOut)),
    );

    _fadeFooter = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );
    _slideFooter = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _emailExpandCtrl.dispose();
    _siEmailCtrl.dispose();
    _siPwCtrl.dispose();
    _suEmailCtrl.dispose();
    _suPwCtrl.dispose();
    _suConfirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final user = await auth.signInWithGoogle(forceAccountPicker: true);
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in was cancelled.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In Error: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signIn() async {
    final email = _siEmailCtrl.text.trim();
    final pw = _siPwCtrl.text;
    if (email.isEmpty || pw.isEmpty) return;

    setState(() { _siLoading = true; _siError = null; });
    try {
      final auth = context.read<AuthProvider>();
      final user = await auth.signInWithEmailAndPassword(email, pw);
      if (!mounted) return;
      if (user == null) {
        setState(() => _siError = 'Invalid email or password. Please try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _siError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _siLoading = false);
    }
  }

  Future<void> _signUp() async {
    final email = _suEmailCtrl.text.trim();
    final pw = _suPwCtrl.text;
    final confirm = _suConfirmPwCtrl.text;

    if (pw != confirm) {
      setState(() => _suError = 'Passwords do not match.');
      return;
    }
    if (pw.length < 8) {
      setState(() => _suError = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _suLoading = true; _suError = null; });
    try {
      final auth = context.read<AuthProvider>();
      final user = await auth.signUpWithEmailAndPassword(email, pw);
      if (!mounted) return;
      if (user == null) {
        setState(() => _suError = 'Could not create account. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        _siEmailCtrl.text = _suEmailCtrl.text;
        setState(() {
          _isSignIn = true;
          _siError = 'Account exists. Enter your password below to sign in.';
        });
      } else {
        setState(() => _suError = _friendlyError(e));
      }
    } catch (e) {
      if (mounted) setState(() => _suError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _suLoading = false);
    }
  }

  String _friendlyError(Object e) {
    String code = '';
    if (e is FirebaseAuthException) code = e.code;
    final msg = e.toString().toLowerCase();
    if (code == 'user-not-found' || msg.contains('user-not-found')) return 'No account found with this email.';
    if (code == 'wrong-password' || msg.contains('wrong-password')) return 'Incorrect password.';
    if (code == 'invalid-credential' || msg.contains('invalid-login-credentials') || msg.contains('invalid-credential')) return 'Incorrect email or password. Please try again.';
    if (code == 'email-already-in-use' || msg.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (msg.contains('network')) return 'Network error. Check your connection.';
    if (e is FirebaseAuthException) return e.message ?? e.code;
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC); // slate-900 / slate-50
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569); // slate-300 / slate-600

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Theme Toggle Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => theme.toggleTheme(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark 
                        ? [] 
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                          size: 14,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDark ? 'Dark' : 'Light',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main Content Centered
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),

                      // Header
                      FadeTransition(
                        opacity: _fadeHeader,
                        child: SlideTransition(
                          position: _slideHeader,
                          child: Column(
                            children: [
                              Text(
                                'Welcome',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your personalized sleep wellness\njourney starts here.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: subTextColor,
                                  height: 1.5,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Google Button
                      FadeTransition(
                        opacity: _fadeGoogleBtn,
                        child: SlideTransition(
                          position: _slideGoogleBtn,
                          child: _buildGoogleButton(isDark),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Email Button
                      FadeTransition(
                        opacity: _fadeEmailBtn,
                        child: SlideTransition(
                          position: _slideEmailBtn,
                          child: Column(
                            children: [
                              _buildEmailButton(isDark),
                              
                              // Expandable Email Form
                              AnimatedSize(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                child: _emailExpanded
                                    ? _buildEmailForm(isDark)
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 12),
                              if (!_emailExpanded)
                                GestureDetector(
                                  onTap: () => setState(() => _emailExpanded = true),
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Already have an account? ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Log in',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: FadeTransition(
                opacity: _fadeFooter,
                child: SlideTransition(
                  position: _slideFooter,
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _googleLoading ? null : _googleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB), // blue-600
          disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF60A5FA).withValues(alpha: 0.4)),
          ),
          elevation: 0,
        ),
        child: _googleLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    padding: const EdgeInsets.all(4),
                    child: Center(
                      child: Image.asset('assets/images/google_logo.png'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmailButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          setState(() => _emailExpanded = !_emailExpanded);
          if (_emailExpanded) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              FocusScope.of(context).requestFocus(FocusNode());
            });
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155).withValues(alpha: 0.8) : const Color(0xFFE2E8F0),
            ),
          ),
          elevation: isDark ? 0 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), size: 18),
            const SizedBox(width: 12),
            Text(
              'Continue with Email',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeToggle(isDark),
          const SizedBox(height: 20),
          if (_isSignIn) _buildSignInFields(isDark) else _buildSignUpFields(isDark),
        ],
      ),
    );
  }

  Widget _buildModeToggle(bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _modeTab('Sign In', _isSignIn, () => setState(() { _isSignIn = true; _siError = null; }), isDark),
          _modeTab('Create Account', !_isSignIn, () => setState(() { _isSignIn = false; _suError = null; }), isDark),
        ],
      ),
    );
  }

  Widget _modeTab(String label, bool active, VoidCallback onTap, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent, // blue-600
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: active ? Colors.white : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInFields(bool isDark) {
    final canSubmit = _siEmailCtrl.text.contains('@') && _siPwCtrl.text.length >= 6 && !_siLoading;
    return Column(
      children: [
        _field(controller: _siEmailCtrl, label: 'Email address', icon: Icons.mail_outline_rounded, isDark: isDark, onChanged: () => setState(() => _siError = null)),
        const SizedBox(height: 12),
        _field(
          controller: _siPwCtrl, label: 'Password', icon: Icons.lock_outline_rounded, isDark: isDark, obscure: !_siShowPw,
          suffixIcon: IconButton(icon: Icon(_siShowPw ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38), onPressed: () => setState(() => _siShowPw = !_siShowPw)),
          onChanged: () => setState(() => _siError = null),
        ),
        if (_siError != null) Padding(padding: const EdgeInsets.only(top: 8), child: _errorBanner(_siError!)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: canSubmit ? _signIn : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _siLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Sign In', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpFields(bool isDark) {
    final passwordsMatch = _suPwCtrl.text == _suConfirmPwCtrl.text;
    final canSubmit = _suEmailCtrl.text.contains('@') && _suPwCtrl.text.length >= 8 && passwordsMatch && !_suLoading;
    return Column(
      children: [
        _field(controller: _suEmailCtrl, label: 'Email address', icon: Icons.mail_outline_rounded, isDark: isDark, onChanged: () => setState(() => _suError = null)),
        const SizedBox(height: 12),
        _field(
          controller: _suPwCtrl, label: 'Password', icon: Icons.lock_outline_rounded, isDark: isDark, obscure: !_suShowPw,
          suffixIcon: IconButton(icon: Icon(_suShowPw ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38), onPressed: () => setState(() => _suShowPw = !_suShowPw)),
          onChanged: () => setState(() => _suError = null),
        ),
        const SizedBox(height: 12),
        _field(
          controller: _suConfirmPwCtrl, label: 'Confirm password', icon: Icons.lock_outline_rounded, isDark: isDark, obscure: !_suShowConfirm,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_suConfirmPwCtrl.text.isNotEmpty) Icon(passwordsMatch ? Icons.check_circle_rounded : Icons.cancel_rounded, color: passwordsMatch ? AppTheme.accentTeal : AppTheme.error, size: 18),
              IconButton(icon: Icon(_suShowConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38), onPressed: () => setState(() => _suShowConfirm = !_suShowConfirm)),
            ],
          ),
          onChanged: () => setState(() => _suError = null),
        ),
        if (_suError != null) Padding(padding: const EdgeInsets.only(top: 8), child: _errorBanner(_suError!)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: canSubmit ? _signUp : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _suLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Create Account', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    Widget? suffixIcon,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12),
        prefixIcon: Icon(icon, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(Icons.error_outline, color: AppTheme.error, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(color: AppTheme.error, fontSize: 11))),
      ]),
    );
  }
}
