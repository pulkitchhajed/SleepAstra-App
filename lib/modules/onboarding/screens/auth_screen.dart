import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/animated_sleep_background.dart';

/// The single entry-point for all authentication flows.
/// Replaces both WelcomeScreen and SignupStepScreen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Sign In controllers
  final _siEmailCtrl = TextEditingController();
  final _siPwCtrl = TextEditingController();
  bool _siShowPw = false;
  bool _siLoading = false;
  String? _siError;

  // Sign Up controllers
  final _suEmailCtrl = TextEditingController();
  final _suPwCtrl = TextEditingController();
  final _suConfirmPwCtrl = TextEditingController();
  bool _suShowPw = false;
  bool _suShowConfirm = false;
  bool _suLoading = false;
  String? _suError;

  bool _googleLoading = false;
  final bool _phoneLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      // Rebuild to animate to the correct dynamic height when tab changes
      if (!_tabCtrl.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _siEmailCtrl.dispose();
    _siPwCtrl.dispose();
    _suEmailCtrl.dispose();
    _suPwCtrl.dispose();
    _suConfirmPwCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    final email = _siEmailCtrl.text.trim();
    final pw = _siPwCtrl.text;
    if (email.isEmpty || pw.isEmpty) return;

    setState(() { _siLoading = true; _siError = null; });
    try {
      final auth = context.read<AuthProvider>();
      final user = await auth.signInWithEmailAndPassword(email, pw);
      // _AppGate watches auth state and routes automatically.
      // No manual navigation needed here.
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
      // _AppGate watches auth state and routes automatically.
      if (!mounted) return;
      if (user == null) {
        setState(() => _suError = 'Could not create account. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'email-already-in-use') {
        // Auto-fill sign in tab and switch to it
        _siEmailCtrl.text = _suEmailCtrl.text;
        _tabCtrl.animateTo(0);
        setState(() => _siError = 'Account exists. Enter your password below to sign in.');
      } else {
        setState(() => _suError = _friendlyError(e));
      }
    } catch (e) {
      if (mounted) setState(() => _suError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _suLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; });
    try {
      final auth = context.read<AuthProvider>();
      await auth.signInWithGoogle(forceAccountPicker: true);
      // _AppGate watches auth state and routes automatically.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e)),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }


  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _siEmailCtrl.text);
    bool loading = false;
    String? error;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reset Password',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your email address below and we will send you a secure link to reset your password.',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _field(
                controller: emailCtrl,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                onChanged: () => setDialogState(() => error = null),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                _errorBanner(error!),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  setDialogState(() => error = 'Please enter a valid email.');
                  return;
                }
                setDialogState(() => loading = true);
                try {
                  final scaffoldMessenger = ScaffoldMessenger.of(this.context);
                  await ctx.read<AuthProvider>().sendPasswordResetEmail(email);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (mounted) { scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Password reset email sent to $email.'),
                      backgroundColor: AppTheme.success,
                    ),
                  ); }
                } catch (e) {
                  setDialogState(() {
                    loading = false;
                    error = _friendlyError(e);
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Send Link', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    String code = '';
    if (e is FirebaseAuthException) code = e.code;
    final msg = e.toString().toLowerCase();
    if (code == 'user-not-found' || msg.contains('user-not-found')) return 'No account found with this email.';
    if (code == 'wrong-password' || msg.contains('wrong-password')) return 'Incorrect password.';
    if (code == 'invalid-credential' || msg.contains('invalid-login-credentials') || msg.contains('invalid-credential')) return 'Incorrect email or password. Please try again.';
    if (code == 'email-already-in-use' || msg.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (code == 'weak-password' || msg.contains('weak-password')) return 'Please choose a stronger password (min. 8 characters).';
    if (code == 'invalid-email' || msg.contains('invalid-email')) return 'Please enter a valid email address.';
    if (code == 'too-many-requests' || msg.contains('too-many-requests')) return 'Too many attempts. Please wait a moment and try again.';
    if (code == 'operation-not-allowed' || msg.contains('operation-not-allowed')) return 'Sign-in method is disabled in Firebase. Please enable it in the console.';
    if (code == 'invalid-phone-number' || msg.contains('invalid-phone-number')) return 'The format of the phone number is incorrect.';
    if (code == 'session-expired' || msg.contains('session-expired')) return 'SMS verification code has expired. Please request a new code.';
    if (code == 'invalid-verification-code' || msg.contains('invalid-verification-code')) return 'Invalid verification code. Please check and try again.';
    if (msg.contains('network')) return 'Network error. Check your connection.';
    
    // Fallback: show the actual raw error so the user (and we) can debug it
    if (e is FirebaseAuthException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: AnimatedSleepBackground(
          child: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildFeatureRow(),
                      const SizedBox(height: 8),
                      _buildAuthCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
      child: Column(
        children: [
          // Logo container
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.primaryIndigo.withValues(alpha: 0.5),
                AppTheme.primaryIndigo.withValues(alpha: 0.05),
              ]),
              border: Border.all(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 2),
              ],
            ),
            child: const Center(
                child: Text('🌙', style: TextStyle(fontSize: 44))),
          ),
          const SizedBox(height: 20),
          Text('SnoreClinics AI',
              style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -1)),
          const SizedBox(height: 8),
          Text(
            'Clinical-grade sleep intelligence\nin the palm of your hand.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureRow() {
    const features = [
      ('🎙️', 'Record'),
      ('🧠', 'AI Analysis'),
      ('📊', 'Insights'),
      ('💬', 'Nidra AI'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: features.map((f) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(children: [
              Text(f.$1, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(f.$2,
                  style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppTheme.primaryIndigo,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500, fontSize: 14),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Create Account'),
                ],
              ),
            ),
          ),
          // Dynamic dynamic-height Tab Content
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: _tabCtrl.index == 0
                ? (_siError != null ? 320.0 : 270.0)
                : (_suError != null ? 360.0 : 310.0),
            child: TabBarView(
              controller: _tabCtrl,
              physics: const NeverScrollableScrollPhysics(), // Require tab taps for synchronized height
              children: [_buildSignIn(), _buildSignUp()],
            ),
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                  child: Divider(color: AppTheme.cardBorder.withValues(alpha: 0.6))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or continue with',
                    style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12)),
              ),
              Expanded(
                  child: Divider(color: AppTheme.cardBorder.withValues(alpha: 0.6))),
            ]),
          ),
          const SizedBox(height: 16),
          // Google & Phone buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                _buildGoogleButton(),
                const SizedBox(height: 12),
                _buildPhoneButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignIn() {
    final canSubmit = _siEmailCtrl.text.contains('@') &&
        _siPwCtrl.text.length >= 6 &&
        !_siLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          _field(
            controller: _siEmailCtrl,
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            onChanged: () => setState(() { _siError = null; }),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _siPwCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: !_siShowPw,
            suffixIcon: IconButton(
              icon: Icon(_siShowPw ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20, color: AppTheme.textSecondary),
              onPressed: () => setState(() => _siShowPw = !_siShowPw),
            ),
            onChanged: () => setState(() { _siError = null; }),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryIndigo,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_siError != null) ...[
            const SizedBox(height: 6),
            _errorBanner(_siError!),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: canSubmit ? _signIn : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit
                    ? AppTheme.primaryIndigo
                    : AppTheme.primaryIndigo.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: canSubmit ? 4 : 0,
                shadowColor: AppTheme.primaryIndigo.withValues(alpha: 0.5),
              ),
              child: _siLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Sign In',
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUp() {
    final passwordsMatch = _suPwCtrl.text == _suConfirmPwCtrl.text;
    final canSubmit = _suEmailCtrl.text.contains('@') &&
        _suPwCtrl.text.length >= 8 &&
        passwordsMatch &&
        !_suLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          _field(
            controller: _suEmailCtrl,
            label: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            onChanged: () => setState(() { _suError = null; }),
          ),
          const SizedBox(height: 10),
          _field(
            controller: _suPwCtrl,
            label: 'Password  (min. 8 characters)',
            icon: Icons.lock_outline_rounded,
            obscure: !_suShowPw,
            suffixIcon: IconButton(
              icon: Icon(_suShowPw ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20, color: AppTheme.textSecondary),
              onPressed: () => setState(() => _suShowPw = !_suShowPw),
            ),
            onChanged: () => setState(() { _suError = null; }),
          ),
          const SizedBox(height: 10),
          _field(
            controller: _suConfirmPwCtrl,
            label: 'Confirm password',
            icon: Icons.lock_outline_rounded,
            obscure: !_suShowConfirm,
            suffixIcon: IconButton(
              icon: Icon(_suShowConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20, color: AppTheme.textSecondary),
              onPressed: () => setState(() => _suShowConfirm = !_suShowConfirm),
            ),
            trailing: _suConfirmPwCtrl.text.isNotEmpty
                ? Icon(
                    passwordsMatch ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: passwordsMatch ? AppTheme.success : AppTheme.error,
                    size: 20)
                : null,
            onChanged: () => setState(() { _suError = null; }),
          ),
          if (_suError != null) ...[
            const SizedBox(height: 8),
            _errorBanner(_suError!),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: canSubmit ? _signUp : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit
                    ? AppTheme.primaryIndigo
                    : AppTheme.primaryIndigo.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: canSubmit ? 4 : 0,
                shadowColor: AppTheme.primaryIndigo.withValues(alpha: 0.5),
              ),
              child: _suLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Create Account',
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton(
        onPressed: _googleLoading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _googleLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.black45, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Google "G" styled manually
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)
                    ],
                  ),
                  child: const Center(
                    child: Text('G',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4285F4))),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Continue with Google',
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ]),
      ),
    );
  }

  Widget _buildPhoneButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton(
        onPressed: _phoneLoading ? null : _startPhoneAuthFlow,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _phoneLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.black45, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone_android_rounded, color: AppTheme.primaryIndigo, size: 22),
                const SizedBox(width: 14),
                Text('Continue with Phone',
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
              ]),
      ),
    );
  }

  void _startPhoneAuthFlow() {
    final phoneCtrl = TextEditingController(text: '+');
    final otpCtrl = TextEditingController();
    String? verificationId;
    String? phoneError;
    bool smsSent = false;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding > 0 ? bottomPadding + 20 : 40),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  smsSent ? 'Verify Phone Code' : 'Phone Authentication',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  smsSent
                      ? 'Enter the 6-digit SMS verification code sent to ${phoneCtrl.text}.'
                      : 'Enter your phone number (including country code, e.g., +91 or +44) to receive an SMS OTP verification.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (!smsSent)
                  _field(
                    controller: phoneCtrl,
                    label: 'Phone number (e.g., +91 1234567890)',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    onChanged: () => setSheetState(() => phoneError = null),
                  )
                else
                  _field(
                    controller: otpCtrl,
                    label: 'Verification code',
                    icon: Icons.sms_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: () => setSheetState(() => phoneError = null),
                  ),
                if (phoneError != null) ...[
                  const SizedBox(height: 12),
                  _errorBanner(phoneError!),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final auth = ctx.read<AuthProvider>();
                          if (!smsSent) {
                            final number = phoneCtrl.text.trim();
                            if (number.length < 8 || !number.startsWith('+')) {
                              setSheetState(() => phoneError = 'Please enter a valid phone number starting with country code (e.g., +91).');
                              return;
                            }
                            setSheetState(() {
                              submitting = true;
                              phoneError = null;
                            });
                            try {
                              await auth.verifyPhoneNumber(
                                number,
                                onCodeSent: (id) {
                                  setSheetState(() {
                                    verificationId = id;
                                    smsSent = true;
                                    submitting = false;
                                    phoneError = null;
                                  });
                                },
                                onVerificationFailed: (e) {
                                  setSheetState(() {
                                    submitting = false;
                                    phoneError = _friendlyError(e);
                                  });
                                },
                              );
                            } catch (e) {
                              setSheetState(() {
                                submitting = false;
                                phoneError = _friendlyError(e);
                              });
                            }
                          } else {
                            final otp = otpCtrl.text.trim();
                            if (otp.length != 6) {
                              setSheetState(() => phoneError = 'Verification code must be exactly 6 digits.');
                              return;
                            }
                            if (verificationId == null) {
                              setSheetState(() => phoneError = 'Verification expired. Please try again.');
                              return;
                            }
                            setSheetState(() {
                              submitting = true;
                              phoneError = null;
                            });
                            try {
                              final scaffoldMessenger = ScaffoldMessenger.of(this.context);
                              final user = await auth.signInWithPhoneCredential(verificationId!, otp);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (user == null && mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Phone sign-in failed. Please try again.'),
                                    backgroundColor: AppTheme.error,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() {
                                submitting = false;
                                phoneError = _friendlyError(e);
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          smsSent ? 'Verify & Login' : 'Send Code',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
                if (smsSent) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => setSheetState(() {
                              smsSent = false;
                              otpCtrl.clear();
                              phoneError = null;
                            }),
                    child: Text(
                      '← Back to Phone Number',
                      style: GoogleFonts.outfit(color: AppTheme.primaryIndigo, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    Widget? trailing,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 15),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(
            color: AppTheme.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: trailing != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                trailing,
                if (suffixIcon != null) suffixIcon,
              ])
            : suffixIcon,
        filled: true,
        fillColor: AppTheme.background.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppTheme.primaryIndigo, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: GoogleFonts.outfit(
                  color: AppTheme.error, fontSize: 13)),
        ),
      ]),
    );
  }
}
