import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Authentication operations.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = kIsWeb 
      ? GoogleSignIn() 
      : GoogleSignIn(serverClientId: '840529050371-2r0lf2ukmtieqo5r8bfbloeqjaloui6l.apps.googleusercontent.com');

  /// Stream of user state changes.
  Stream<User?> get userChanges => _auth.userChanges();

  /// Currently logged in user.
  User? get currentUser => _auth.currentUser;

  /// Returns true if the current user is logged in with a permanent account.
  bool get isAuthenticated => currentUser != null && !currentUser!.isAnonymous;

  /// Guest sign in (Anonymous).
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } catch (e) {
      debugPrint('AuthService: Anonymous Sign-in Error: $e');
      return null;
    }
  }

  /// Google Sign In. Attempts silent sign-in first for returning users.
  /// Only shows the account picker if the user has never signed in before
  /// or if the silent sign-in token has expired.
  Future<User?> signInWithGoogle({bool forceAccountPicker = false}) async {
    try {
      GoogleSignInAccount? googleUser;

      // 1. Try silent sign-in first (no UI shown if already signed in)
      if (!forceAccountPicker) {
        googleUser = await _googleSignIn.signInSilently();
      }

      // 2. Fall back to interactive picker only if silent fails
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // If user is already an anonymous guest, link the accounts.
      final user = currentUser;
      if (user != null && user.isAnonymous) {
        final result = await user.linkWithCredential(credential);
        return result.user;
      }

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint('AuthService: Google Sign-in Error: $e');
      return null;
    }
  }

  /// Verify Phone Number (triggers SMS verification code)
  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Automatic SMS resolution on some Android devices
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Sign In with Phone verification credential
  Future<User?> signInWithPhoneCredential(String verificationId, String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // If user is already an anonymous guest, link the accounts
      final user = currentUser;
      if (user != null && user.isAnonymous) {
        final result = await user.linkWithCredential(credential);
        return result.user;
      }

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint('AuthService: Phone Sign-in Error: $e');
      // Rethrow so the UI can show specific error (like invalid code)
      rethrow;
    }
  }

  /// Email/Password Sign Up
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    // Let FirebaseAuthException propagate so the UI can show specific messages.
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  /// Email/Password Sign In
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    // Let FirebaseAuthException propagate so the UI can show specific messages.
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      // Run google sign out asynchronously so it doesn't block the UI if Google Play Services hangs
      _googleSignIn.signOut().catchError((e) {
        debugPrint('AuthService: Google Sign-out Error: $e');
        return null;
      });
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService: Sign-out Error: $e');
    }
  }
}
