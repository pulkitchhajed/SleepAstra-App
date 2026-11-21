import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../../modules/blogs/services/blog_service.dart';
import '../../modules/videos/services/video_service.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Provider to manage Authentication state across the app.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String _role = 'user';
  int _sessionKey = 0;
  bool _isDisposed = false;
  late final StreamSubscription<User?> _authSubscription;

  AuthProvider() {
    _user = _authService.currentUser;
    if (_user != null) {
      _fetchRole();
      // Seed only once — guard against double-call when auth stream
      // fires immediately on subscribe for an already-logged-in user.
      _triggerSeedOnce();
    }
    // Listen to auth changes for future updates.
    _authSubscription = _authService.userChanges.listen((User? user) async {
      _user = user;
      _role = 'user'; // Immediately reset role to user
      await _fetchRole();
      if (user != null) {
        _triggerSeedOnce();
        _updateFcmToken(user.uid);
      }
      if (!_isDisposed) notifyListeners();
    });
  }

  bool _seeded = false;

  void _triggerSeedOnce() {
    if (_seeded) return;
    _seeded = true;
    // BlogService.seedDemoBlogs();
    // VideoService.seedDemoVideos();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription.cancel();
    super.dispose();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && !_user!.isAnonymous;
  String? get uid => _user?.uid;
  int get sessionKey => _sessionKey;

  /// True when the signed-in user has role == 'admin' in Firestore.
  bool get isAdmin => _role == 'admin';

  /// Whitelisted admin emails with immediate bootstrap access
  static const List<String> defaultAdmins = [
    'vennelareddy06@gmail.com',
    'sureshmereddy76@gmail.com',
    'sureshmereddy@snoreclinics.org',
    'pulkitchhajed29@gmail.com',
    'balchander18@gmail.com',
    'nadeemfazlullah@gmail.com',
  ];

  static const List<String> hardcodedAdmins = defaultAdmins;

  /// Ensures all default administrators are seeded in the Firestore /admins collection
  static Future<void> ensureAllDefaultAdmins() async {
    try {
      final adminsCol = FirebaseFirestore.instance.collection('admins');
      for (final email in defaultAdmins) {
        final docRef = adminsCol.doc(email);
        final snap = await docRef.get();
        if (!snap.exists) {
          await docRef.set({
            'email': email,
            'active': true,
            'addedAt': FieldValue.serverTimestamp(),
            'addedBy': 'System',
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] ensureAllDefaultAdmins error: $e');
    }
  }

  /// Explicitly re-checks role and returns true if user has admin privileges.
  Future<bool> verifyAndRefreshAdminStatus() async {
    await _fetchRole();
    if (!_isDisposed) notifyListeners();
    return isAdmin;
  }

  /// Fetches the role field strictly from default admin whitelist or admins collection only.
  Future<void> _fetchRole() async {
    try {
      final email = _user?.email?.toLowerCase().trim();
      if (_user == null || email == null || email.isEmpty) {
        _role = 'user';
        return;
      }

      // 1. Check default admin whitelist
      if (defaultAdmins.contains(email)) {
        _role = 'admin';
        // Auto-seed this admin to /admins collection if not yet present
        _ensureAdminDocExists(email);
        return;
      }

      // 2. Strict Whitelist in /admins collection (must exist and have active == true)
      final adminSnap = await FirebaseFirestore.instance
          .collection('admins')
          .doc(email)
          .get();
      if (adminSnap.exists && adminSnap.data()?['active'] == true) {
        _role = 'admin';
        return;
      }

      // 3. Any other user is strictly non-admin
      _role = 'user';
    } catch (_) {
      _role = 'user';
    }
  }

  static Future<void> _ensureAdminDocExists(String email) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('admins').doc(email);
      final snap = await docRef.get();
      if (!snap.exists) {
        await docRef.set({
          'email': email,
          'active': true,
          'addedAt': FieldValue.serverTimestamp(),
          'addedBy': 'System',
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> _updateFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  /// Guest Login.
  Future<void> signInAnonymously() async {
    _setLoading(true);
    final guestUid = await FirestoreService.deviceUid;
    final user = await _authService.signInAnonymously();
    
    // Migrate data from old system device ID to the new anonymous UID
    if (user != null && guestUid != user.uid) {
      await FirestoreService.migrateGuestData(guestUid, user.uid);
    }
    
    _setLoading(false);
  }

  /// Verify Phone Number
  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
  }) async {
    _setLoading(true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber,
        onCodeSent: (verificationId) {
          _setLoading(false);
          onCodeSent(verificationId);
        },
        onVerificationFailed: (e) {
          _setLoading(false);
          onVerificationFailed(e);
        },
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  /// Sign In with Phone verification credential
  Future<User?> signInWithPhoneCredential(String verificationId, String smsCode) async {
    _setLoading(true);
    try {
      final guestUid = await FirestoreService.deviceUid;
      final user = await _authService.signInWithPhoneCredential(verificationId, smsCode);
      
      // Migrate data if we transition from guest to a permanent UID
      if (user != null && guestUid != user.uid) {
        await FirestoreService.migrateGuestData(guestUid, user.uid);
        _user = user;
      }
      return user;
    } finally {
      _setLoading(false);
    }
  }

  /// Google Login. Attempts silent sign-in first for returning users.
  /// Pass [forceAccountPicker] = true to force the account selection UI
  /// (e.g. when user explicitly wants to switch accounts).
  Future<User?> signInWithGoogle({bool forceAccountPicker = false}) async {
    _setLoading(true);
    try {
      final guestUid = await FirestoreService.deviceUid;
      final user = await _authService.signInWithGoogle(
        forceAccountPicker: forceAccountPicker,
      );
      
      // Migrate data if we transition from guest to a permanent UID
      if (user != null && guestUid != user.uid) {
        await FirestoreService.migrateGuestData(guestUid, user.uid, email: user.email);
      }
      
      // Update local state immediately so subsequent calls have the user available
      if (user != null) {
        _user = user;
        // BULLETPROOF: Save the email explicitly to Firestore immediately
        if (user.email != null) {
          await FirestoreService.saveEmail(user.uid, user.email!);
        }
      }
      return user;
    } finally {
      _setLoading(false);
    }
  }

  /// Email Sign Up
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    try {
      final guestUid = await FirestoreService.deviceUid;
      final user = await _authService.signUpWithEmailAndPassword(email, password);
      
      if (user != null && guestUid != user.uid) {
        await FirestoreService.migrateGuestData(guestUid, user.uid, email: email);
        _user = user;
        // BULLETPROOF: Save the email explicitly to Firestore immediately
        await FirestoreService.saveEmail(user.uid, email);
      }
      
      return user;
    } finally {
      _setLoading(false);
    }
  }

  /// Email Sign In
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    try {
      final guestUid = await FirestoreService.deviceUid;
      final user = await _authService.signInWithEmailAndPassword(email, password);
      
      if (user != null && guestUid != user.uid) {
        await FirestoreService.migrateGuestData(guestUid, user.uid, email: email);
        _user = user;
        // BULLETPROOF: Save the email explicitly to Firestore immediately
        await FirestoreService.saveEmail(user.uid, email);
      }
      
      return user;
    } finally {
      _setLoading(false);
    }
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    // Clear the cached device UID so the next login starts fresh
    await FirestoreService.clearCache();
    await _authService.signOut();
    _user = null; // Explicitly set to null to avoid waiting for stream
    _role = 'user'; // Explicitly reset role to non-admin user
    _sessionKey++; // Force a sync even if uid is still null (e.g. guest sign out)
    if (!_isDisposed) notifyListeners();
    _setLoading(false);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    if (!_isDisposed) notifyListeners();
  }
}
