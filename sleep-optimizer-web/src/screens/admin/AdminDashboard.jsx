import React, { useState, useEffect } from 'react';
import {
  collection, getDocs, addDoc, doc, getDoc, updateDoc, setDoc, deleteDoc,
  serverTimestamp, onSnapshot, query, orderBy, limit
} from 'firebase/firestore';
import {
  getAuth, signInWithPopup, GoogleAuthProvider,
  signInWithEmailAndPassword, onAuthStateChanged, signOut,
} from 'firebase/auth';
import { db, auth } from '../../firebaseConfig';
import './AdminDashboard.css';

export default function AdminDashboard({ onExit }) {
  // ─── Auth & role state ───────────────────────────────────────────────────────
  const [user, setUser]                 = useState(null);
  const [isAdmin, setIsAdmin]           = useState(false);
  const [authChecked, setAuthChecked]   = useState(false);
  const [authLoading, setAuthLoading]   = useState(false);
  const [authError, setAuthError]       = useState('');
  
  // Fallback email/password login toggle
  const [showEmailLogin, setShowEmailLogin] = useState(false);
  const [authEmail, setAuthEmail]           = useState('');
  const [authPassword, setAuthPassword]     = useState('');

  // ─── Navigation tabs ─────────────────────────────────────────────────────────
  // 'notifications' | 'admin_team' | 'users' | 'audit_logs' | 'overview'
  const [activeTab, setActiveTab]       = useState('notifications');

  // ─── Data states ─────────────────────────────────────────────────────────────
  const [users, setUsers]               = useState([]);
  const [allUsers, setAllUsers]         = useState([]);
  const [adminWhitelist, setAdminWhitelist] = useState([]);
  const [auditLogs, setAuditLogs]       = useState([]);
  const [loading, setLoading]           = useState(true);

  // ─── Notification form state ─────────────────────────────────────────────────
  const [formData, setFormData] = useState({
    title: '', body: '', targetUid: 'all',
    scheduleType: 'now', timerMinutes: 10, bedtimeOffset: -60,
  });
  const [sendingNotif, setSendingNotif] = useState(false);
  const [notifFeedback, setNotifFeedback] = useState({ msg: '', type: '' });

  // ─── Admin Team form state ───────────────────────────────────────────────────
  const [newAdminEmail, setNewAdminEmail] = useState('');
  const [adminTeamLoading, setAdminTeamLoading] = useState(false);
  const [adminTeamFeedback, setAdminTeamFeedback] = useState({ msg: '', type: '' });

  // ─── Audit Log search & filter ───────────────────────────────────────────────
  const [logSearch, setLogSearch]       = useState('');
  const [logFilterAction, setLogFilterAction] = useState('ALL');

  // ─── Users search filter ─────────────────────────────────────────────────────
  const [userSearch, setUserSearch]     = useState('');

  // ─── Copy URL state ──────────────────────────────────────────────────────────
  const [copiedUrl, setCopiedUrl]       = useState(false);

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. Audit Logging Service
  // ─────────────────────────────────────────────────────────────────────────────
  const logAdminActivity = async (action, details, target = null, extra = {}) => {
    try {
      const currentUser = auth.currentUser;
      const logPayload = {
        action,
        details,
        target: target || null,
        adminEmail: currentUser?.email || user?.email || 'unauthenticated',
        adminUid: currentUser?.uid || user?.uid || 'unauthenticated',
        timestamp: serverTimestamp(),
        createdAt: new Date().toISOString(),
        userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : 'web',
        ...extra,
      };
      await addDoc(collection(db, 'admin_logs'), logPayload);
    } catch (err) {
      console.warn('[AdminLogger] Failed to write log:', err);
    }
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. Multi-tier Firestore Admin Access Check
  // ─────────────────────────────────────────────────────────────────────────────
  const verifyAdminAccess = async (firebaseUser) => {
    if (!firebaseUser) return false;
    const email = (firebaseUser.email || '').toLowerCase().trim();
    const uid = firebaseUser.uid;

    try {
      // 0. Primary Admin Whitelist
      const primaryAdmins = [
        'vennelareddy06@gmail.com',
        'sureshmereddy76@gmail.com',
        'sureshmereddy@snoreclinics.org',
        'pulkitchhajed29@gmail.com',
        'balchander18@gmail.com',
        'nadeemfazlullah@gmail.com',
      ];
      if (email && primaryAdmins.includes(email)) {
        await setDoc(doc(db, 'admins', email), {
          email,
          uid,
          role: 'admin',
          lastLogin: serverTimestamp(),
          active: true,
        }, { merge: true }).catch(() => {});
        await setDoc(doc(db, 'users', uid), {
          role: 'admin',
          email,
          lastLogin: serverTimestamp(),
        }, { merge: true }).catch(() => {});
        return true;
      }

      // 1. Check 'admins' collection by email (Primary Whitelist)
      if (email) {
        const adminDoc = await getDoc(doc(db, 'admins', email));
        if (adminDoc.exists() && adminDoc.data()?.active !== false) {
          // Sync user's UID to the admin record
          await setDoc(doc(db, 'admins', email), {
            uid,
            lastLogin: serverTimestamp(),
            active: true,
          }, { merge: true }).catch(() => {});

          await setDoc(doc(db, 'users', uid), {
            role: 'admin',
            email,
            lastLogin: serverTimestamp(),
          }, { merge: true }).catch(() => {});

          return true;
        }
      }

      // 2. Check 'users' collection by UID
      const userDoc = await getDoc(doc(db, 'users', uid));
      if (userDoc.exists() && userDoc.data()?.role === 'admin') {
        if (email) {
          await setDoc(doc(db, 'admins', email), {
            email,
            uid,
            role: 'admin',
            lastLogin: serverTimestamp(),
            active: true,
          }, { merge: true }).catch(() => {});
        }
        return true;
      }

      // 3. Check 'profiles_by_email' collection by email
      if (email) {
        const profileDoc = await getDoc(doc(db, 'profiles_by_email', email));
        if (profileDoc.exists() && profileDoc.data()?.role === 'admin') {
          await setDoc(doc(db, 'admins', email), {
            email,
            uid,
            role: 'admin',
            lastLogin: serverTimestamp(),
            active: true,
          }, { merge: true }).catch(() => {});
          return true;
        }
      }
    } catch (err) {
      console.error('[AdminCheck] Error verifying admin access:', err);
    }

    return false;
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. Auth Listener & Initialization
  // ─────────────────────────────────────────────────────────────────────────────
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (u) {
        setLoading(true);
        const authorized = await verifyAdminAccess(u);
        setIsAdmin(authorized);

        if (authorized) {
          // Log successful admin session
          await logAdminActivity('ADMIN_LOGIN', `Admin logged in successfully: ${u.email}`, u.email);
          // Load admin collections
          loadAdminData();
        } else {
          // Log unauthorized access attempt
          await logAdminActivity('UNAUTHORIZED_ACCESS_ATTEMPT', `Unauthorized access attempt by: ${u.email}`, u.email);
          setLoading(false);
        }
      } else {
        setIsAdmin(false);
        setLoading(false);
      }
      setAuthChecked(true);
    });

    return () => unsubscribe();
  }, []);

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. Real-time Audit Logs & Data Fetching
  // ─────────────────────────────────────────────────────────────────────────────
  const loadAdminData = () => {
    fetchUsers();
    fetchAdminWhitelist();
  };

  // Real-time listener for audit logs when admin is authorized
  useEffect(() => {
    if (!isAdmin) return;

    const q = query(
      collection(db, 'admin_logs'),
      orderBy('timestamp', 'desc'),
      limit(100)
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const logs = [];
      snapshot.forEach((d) => {
        logs.push({ id: d.id, ...d.data() });
      });
      setAuditLogs(logs);
    }, (err) => {
      console.warn('Real-time audit logs listener error:', err);
    });

    return () => unsubscribe();
  }, [isAdmin]);

  // Real-time listener for admin whitelist
  const fetchAdminWhitelist = () => {
    const q = query(collection(db, 'admins'));
    return onSnapshot(q, (snapshot) => {
      const list = [];
      snapshot.forEach((d) => {
        list.push({ id: d.id, ...d.data() });
      });
      setAdminWhitelist(list);
    }, (err) => {
      console.warn('Admin whitelist listener error:', err);
    });
  };

  // Fetch users with FCM tokens and general user list
  const fetchUsers = async () => {
    try {
      const snap = await getDocs(collection(db, 'users'));
      const fcmUsers = [];
      const all = [];
      const seenUids = new Set();

      snap.forEach((docSnap) => {
        const data = docSnap.data();
        all.push({ id: docSnap.id, ...data });
        seenUids.add(docSnap.id);
        if (data.fcmToken) fcmUsers.push({ id: docSnap.id, ...data });
      });

      try {
        const emailSnap = await getDocs(collection(db, 'profiles_by_email'));
        emailSnap.forEach((emailDoc) => {
          const eData = emailDoc.data();
          const linkedUid = eData.lastLinkedUid || emailDoc.id;
          if (!seenUids.has(linkedUid)) {
            all.push({ id: linkedUid, email: emailDoc.id, ...eData });
            seenUids.add(linkedUid);
          }
        });
      } catch (err) {
        console.warn('profiles_by_email lookup skipped:', err);
      }

      setUsers(fcmUsers);
      setAllUsers(all);
    } catch (err) {
      console.error('Error fetching users:', err);
    } finally {
      setLoading(false);
    }
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. Auth Handlers (Google Sign-In & Email Fallback)
  // ─────────────────────────────────────────────────────────────────────────────
  const handleGoogleSignIn = async () => {
    setAuthError('');
    setAuthLoading(true);
    try {
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: 'select_account' });
      await signInWithPopup(auth, provider);
      // onAuthStateChanged will handle verification
    } catch (err) {
      console.error('Google Sign-In failed:', err);
      setAuthError(err.message || 'Google Sign-In failed. Please try again.');
    } finally {
      setAuthLoading(false);
    }
  };

  const handleEmailPasswordSignIn = async (e) => {
    e.preventDefault();
    setAuthError('');
    setAuthLoading(true);
    try {
      await signInWithEmailAndPassword(auth, authEmail, authPassword);
    } catch (err) {
      console.error('Email login failed:', err);
      setAuthError(err.message || 'Login failed.');
    } finally {
      setAuthLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      if (user?.email) {
        await logAdminActivity('ADMIN_LOGOUT', `Admin signed out: ${user.email}`, user.email);
      }
      await signOut(auth);
      setIsAdmin(false);
      setUser(null);
    } catch (err) {
      console.error('Logout error:', err);
    }
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. Admin Team / Whitelist Management
  // ─────────────────────────────────────────────────────────────────────────────
  const handleAddAdminByEmail = async (e) => {
    e.preventDefault();
    if (!newAdminEmail || !newAdminEmail.includes('@')) {
      setAdminTeamFeedback({ msg: 'Please provide a valid email address.', type: 'error' });
      return;
    }

    const targetEmail = newAdminEmail.toLowerCase().trim();
    setAdminTeamLoading(true);
    setAdminTeamFeedback({ msg: '', type: '' });

    try {
      // 1. Add to 'admins' collection
      await setDoc(doc(db, 'admins', targetEmail), {
        email: targetEmail,
        role: 'admin',
        active: true,
        addedBy: user?.email || 'admin',
        addedAt: serverTimestamp(),
      }, { merge: true });

      // 2. Add to 'profiles_by_email'
      await setDoc(doc(db, 'profiles_by_email', targetEmail), {
        role: 'admin',
        email: targetEmail,
      }, { merge: true });

      // 3. Log the action
      await logAdminActivity('ADD_ADMIN_EMAIL', `Granted admin access to email: ${targetEmail}`, targetEmail);

      setAdminTeamFeedback({
        msg: `✅ Success! Admin access granted to ${targetEmail}. They can now sign in with Google to access this portal.`,
        type: 'success',
      });
      setNewAdminEmail('');
    } catch (err) {
      console.error('Error adding admin by email:', err);
      setAdminTeamFeedback({ msg: `❌ Failed to add admin: ${err.message}`, type: 'error' });
    } finally {
      setAdminTeamLoading(false);
    }
  };

  const handleToggleAdminStatus = async (adminEntry) => {
    const targetEmail = adminEntry.email || adminEntry.id;
    const isCurrentlyActive = adminEntry.active !== false;
    const newStatus = !isCurrentlyActive;

    setAdminTeamLoading(true);
    try {
      await updateDoc(doc(db, 'admins', targetEmail), {
        active: newStatus,
        updatedAt: serverTimestamp(),
        updatedBy: user?.email || 'admin',
      });

      const action = newStatus ? 'REACTIVATE_ADMIN_EMAIL' : 'REVOKE_ADMIN_EMAIL';
      const actionMsg = newStatus
        ? `Re-activated admin access for: ${targetEmail}`
        : `Revoked admin access for: ${targetEmail}`;

      await logAdminActivity(action, actionMsg, targetEmail);
      setAdminTeamFeedback({ msg: `✅ ${actionMsg}`, type: 'success' });
    } catch (err) {
      console.error('Error updating admin status:', err);
      setAdminTeamFeedback({ msg: `❌ Failed to update status: ${err.message}`, type: 'error' });
    } finally {
      setAdminTeamLoading(false);
    }
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. Push Notification Dispatch
  // ─────────────────────────────────────────────────────────────────────────────
  const handleSendNotification = async (e) => {
    e.preventDefault();
    setSendingNotif(true);
    setNotifFeedback({ msg: '', type: '' });

    try {
      const payload = {
        title: formData.title,
        body: formData.body,
        targetUid: formData.targetUid,
        scheduleType: formData.scheduleType,
        status: 'pending',
        createdAt: serverTimestamp(),
        createdBy: user?.email || 'admin',
      };

      if (formData.targetUid !== 'all') {
        const target = users.find((u) => u.id === formData.targetUid);
        if (target) {
          payload.fcmToken = target.fcmToken;
          payload.bedtime = target.bedtime || '22:30';
          payload.targetEmail = target.email || null;
        }
      }

      if (formData.scheduleType === 'timer') {
        payload.timerMinutes = Number(formData.timerMinutes);
      }
      if (formData.scheduleType === 'bedtime') {
        payload.bedtimeOffsetMinutes = Number(formData.bedtimeOffset);
      }

      const docRef = await addDoc(collection(db, 'scheduled_notifications'), payload);

      // Log activity
      await logAdminActivity(
        'SCHEDULE_NOTIFICATION',
        `Scheduled "${formData.title}" (${formData.scheduleType}) to target: ${formData.targetUid}`,
        docRef.id
      );

      setNotifFeedback({ msg: '✅ Push notification scheduled successfully!', type: 'success' });
      setFormData((prev) => ({ ...prev, title: '', body: '' }));
    } catch (err) {
      console.error('Error scheduling notification:', err);
      setNotifFeedback({ msg: `❌ Failed to schedule notification: ${err.message}`, type: 'error' });
    } finally {
      setSendingNotif(false);
    }
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. User Role Modification
  // ─────────────────────────────────────────────────────────────────────────────
  const handleSetUserRole = async (uid, newRole) => {
    try {
      await setDoc(doc(db, 'users', uid), { role: newRole }, { merge: true });
      const targetUser = allUsers.find((u) => u.id === uid);
      if (targetUser && targetUser.email) {
        const normalized = targetUser.email.toLowerCase();
        await setDoc(doc(db, 'profiles_by_email', normalized), { role: newRole }, { merge: true }).catch(() => {});
        if (newRole === 'admin') {
          await setDoc(doc(db, 'admins', normalized), {
            email: normalized,
            uid,
            role: 'admin',
            active: true,
            addedBy: user?.email || 'admin',
            addedAt: serverTimestamp(),
          }, { merge: true });
        } else {
          await updateDoc(doc(db, 'admins', normalized), { active: false }).catch(() => {});
        }
      }

      setAllUsers((prev) =>
        prev.map((u) => (u.id === uid ? { ...u, role: newRole } : u))
      );

      await logAdminActivity(
        'ROLE_CHANGE',
        `Changed role of user (${uid.substring(0, 8)}…) to "${newRole}"`,
        uid
      );
    } catch (err) {
      console.error('Error updating user role:', err);
    }
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 9. Utility: Copy Admin URL
  // ─────────────────────────────────────────────────────────────────────────────
  const copyAdminUrl = () => {
    const adminUrl = `${window.location.origin}/admin`;
    navigator.clipboard.writeText(adminUrl);
    setCopiedUrl(true);
    setTimeout(() => setCopiedUrl(false), 3000);
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 10. Audit Log Filtered List
  // ─────────────────────────────────────────────────────────────────────────────
  const filteredLogs = auditLogs.filter((log) => {
    const matchSearch =
      !logSearch ||
      (log.adminEmail && log.adminEmail.toLowerCase().includes(logSearch.toLowerCase())) ||
      (log.details && log.details.toLowerCase().includes(logSearch.toLowerCase())) ||
      (log.target && log.target.toLowerCase().includes(logSearch.toLowerCase()));

    const matchAction =
      logFilterAction === 'ALL' ||
      (logFilterAction === 'LOGIN' && (log.action === 'ADMIN_LOGIN' || log.action === 'ADMIN_LOGOUT')) ||
      (logFilterAction === 'ADMINS' && (log.action.includes('ADMIN') || log.action.includes('ROLE'))) ||
      (logFilterAction === 'NOTIF' && log.action.includes('NOTIFICATION')) ||
      (logFilterAction === 'SECURITY' && log.action === 'UNAUTHORIZED_ACCESS_ATTEMPT');

    return matchSearch && matchAction;
  });

  const getBadgeClass = (action = '') => {
    if (action === 'ADMIN_LOGIN' || action === 'ADMIN_LOGOUT') return 'log-badge-login';
    if (action.includes('ADD_ADMIN') || action.includes('GRANT')) return 'log-badge-grant';
    if (action.includes('REVOKE')) return 'log-badge-revoke';
    if (action.includes('NOTIFICATION')) return 'log-badge-notif';
    if (action.includes('UNAUTHORIZED')) return 'log-badge-unauth';
    return 'log-badge-content';
  };

  // ─────────────────────────────────────────────────────────────────────────────
  // 11. Render Guards: Not Authenticated / Unauthorized
  // ─────────────────────────────────────────────────────────────────────────────
  if (!authChecked || (user && loading)) {
    return (
      <div className="admin-loading">
        <div className="admin-spinner" />
        <div>Authenticating with Firestore...</div>
      </div>
    );
  }

  // Not Logged In -> Show Admin Google Sign-In Portal
  if (!user) {
    return (
      <div className="admin-dashboard" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="admin-content" style={{ maxWidth: '440px', width: '100%', textAlign: 'center' }}>
          <div style={{ fontSize: '3rem', marginBottom: '12px' }}>🛡️</div>
          <h1 style={{ fontSize: '1.8rem', fontWeight: 700, margin: '0 0 8px 0', color: '#e0e7ff' }}>
            SleepAstra Admin Portal
          </h1>
          <p style={{ color: '#94a3b8', fontSize: '0.9rem', marginBottom: '28px', lineHeight: 1.5 }}>
            Sign in with your authorized admin Google account to manage push notifications, team permissions, and audit logs.
          </p>

          <button
            type="button"
            className="google-sign-in-btn"
            onClick={handleGoogleSignIn}
            disabled={authLoading}
          >
            <svg width="20" height="20" viewBox="0 0 24 24">
              <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
              <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
              <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z" />
              <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z" />
            </svg>
            {authLoading ? 'Signing in...' : 'Sign in with Google'}
          </button>

          {authError && (
            <div className="form-message error" style={{ textAlign: 'left', marginTop: '16px' }}>
              {authError}
            </div>
          )}

          <div style={{ marginTop: '24px', paddingTop: '20px', borderTop: '1px solid rgba(255,255,255,0.08)' }}>
            <button
              type="button"
              onClick={() => setShowEmailLogin(!showEmailLogin)}
              style={{ background: 'transparent', border: 'none', color: '#94a3b8', fontSize: '0.8rem', cursor: 'pointer', textDecoration: 'underline' }}
            >
              {showEmailLogin ? 'Hide Email & Password Login' : 'Admin Email/Password Fallback'}
            </button>
          </div>

          {showEmailLogin && (
            <form onSubmit={handleEmailPasswordSignIn} style={{ marginTop: '16px', textAlign: 'left' }}>
              <div className="form-group">
                <label>Admin Email</label>
                <input
                  type="email"
                  value={authEmail}
                  onChange={(e) => setAuthEmail(e.target.value)}
                  placeholder="admin@sleepastra.com"
                  required
                />
              </div>
              <div className="form-group">
                <label>Password</label>
                <input
                  type="password"
                  value={authPassword}
                  onChange={(e) => setAuthPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                />
              </div>
              <button type="submit" className="submit-btn" disabled={authLoading}>
                {authLoading ? 'Verifying...' : 'Login with Credentials'}
              </button>
            </form>
          )}

          <div style={{ marginTop: '24px' }}>
            <button
              type="button"
              onClick={onExit || (() => { window.location.href = '/'; })}
              style={{ background: 'transparent', border: 'none', color: '#64748b', fontSize: '0.85rem', cursor: 'pointer' }}
            >
              ← Back to Sleep Optimizer App
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Logged in with Google, but NOT an authorized admin in Firestore
  if (!isAdmin) {
    return (
      <div className="admin-dashboard" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="admin-content" style={{ maxWidth: '480px', width: '100%', textAlign: 'center' }}>
          <div style={{ fontSize: '3rem', marginBottom: '12px' }}>🚫</div>
          <h1 style={{ fontSize: '1.8rem', fontWeight: 700, margin: '0 0 8px 0', color: '#f87171' }}>
            Admin Access Denied
          </h1>
          <p style={{ color: '#cbd5e1', fontSize: '0.95rem', marginBottom: '20px', lineHeight: 1.5 }}>
            Your account <strong style={{ color: '#f8fafc' }}>{user.email}</strong> is not authorized as an administrator.
          </p>

          <div style={{ background: 'rgba(0,0,0,0.3)', padding: '14px', borderRadius: '10px', textAlign: 'left', marginBottom: '24px' }}>
            <div style={{ fontSize: '0.8rem', color: '#94a3b8', marginBottom: '4px' }}>Your Google Account details:</div>
            <div style={{ fontSize: '0.85rem', color: '#38bdf8', wordBreak: 'break-all' }}>Email: {user.email}</div>
            <div style={{ fontSize: '0.8rem', color: '#94a3b8', wordBreak: 'break-all', marginTop: '4px' }}>UID: {user.uid}</div>
          </div>

          <p style={{ color: '#94a3b8', fontSize: '0.85rem', marginBottom: '24px' }}>
            To gain access, request an existing Administrator to add your email <strong style={{ color: '#e2e8f0' }}>({user.email})</strong> to the Admin Whitelist in Firestore.
          </p>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button
              type="button"
              className="submit-btn"
              onClick={handleLogout}
              style={{ background: '#475569' }}
            >
              Sign Out / Switch Account
            </button>
            <button
              type="button"
              className="admin-btn-secondary"
              onClick={onExit || (() => { window.location.href = '/'; })}
              style={{ flex: 1, justifyContent: 'center' }}
            >
              Return to App
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 12. Full Authorized Admin Dashboard
  // ─────────────────────────────────────────────────────────────────────────────
  return (
    <div className="admin-dashboard">
      {/* Top Banner: Easy URL Sharing */}
      <div className="admin-url-banner">
        <div className="admin-url-text">
          <span>🔗 <strong>Admin Portal Direct URL:</strong></span>
          <span className="admin-url-code">{window.location.origin}/admin</span>
        </div>
        <button type="button" className="admin-btn-secondary" onClick={copyAdminUrl}>
          {copiedUrl ? '✅ Link Copied to Clipboard!' : '📋 Copy Admin URL to Share'}
        </button>
      </div>

      {/* Header */}
      <div className="admin-header">
        <div>
          <h1>🛡️ SleepAstra Admin Portal</h1>
          <p>Centralized Firestore management, team delegation, and activity auditing</p>
        </div>

        <div className="admin-user-profile">
          {user.photoURL && (
            <img src={user.photoURL} alt="Admin avatar" className="admin-avatar" />
          )}
          <div className="admin-user-details">
            <span className="admin-user-name">{user.displayName || 'Authorized Admin'}</span>
            <span className="admin-user-email">{user.email}</span>
          </div>

          <div style={{ display: 'flex', gap: '8px', marginLeft: '12px' }}>
            <button
              type="button"
              onClick={onExit || (() => { window.location.href = '/'; })}
              className="admin-btn-secondary"
              title="Return to user sleep optimizer web application"
            >
              📱 Web App
            </button>
            <button
              type="button"
              onClick={handleLogout}
              className="admin-btn-secondary"
              style={{ background: 'rgba(239, 68, 68, 0.15)', color: '#fca5a5', borderColor: 'rgba(239, 68, 68, 0.3)' }}
            >
              Logout
            </button>
          </div>
        </div>
      </div>

      {/* Quick Stats Grid */}
      <div className="admin-stats-grid">
        <div className="admin-stat-card">
          <div className="admin-stat-label">Registered Users</div>
          <div className="admin-stat-value">{allUsers.length}</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Authorized Admins</div>
          <div className="admin-stat-value">{adminWhitelist.filter(a => a.active !== false).length}</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">FCM Target Devices</div>
          <div className="admin-stat-value">{users.length}</div>
        </div>
        <div className="admin-stat-card">
          <div className="admin-stat-label">Audit Logs Recorded</div>
          <div className="admin-stat-value">{auditLogs.length}</div>
        </div>
      </div>

      {/* Tabs */}
      <div className="admin-tabs">
        <button
          className={`admin-tab-btn ${activeTab === 'notifications' ? 'active' : ''}`}
          onClick={() => setActiveTab('notifications')}
        >
          📢 Push Notifications
        </button>
        <button
          className={`admin-tab-btn ${activeTab === 'admin_team' ? 'active' : ''}`}
          onClick={() => setActiveTab('admin_team')}
        >
          🛡️ Admin Team (Email Access)
        </button>
        <button
          className={`admin-tab-btn ${activeTab === 'users' ? 'active' : ''}`}
          onClick={() => setActiveTab('users')}
        >
          👥 User Directory ({allUsers.length})
        </button>
        <button
          className={`admin-tab-btn ${activeTab === 'audit_logs' ? 'active' : ''}`}
          onClick={() => setActiveTab('audit_logs')}
        >
          📋 Activity Audit Logs ({auditLogs.length})
        </button>
      </div>

      {/* ── TAB 1: Push Notifications ── */}
      {activeTab === 'notifications' && (
        <div className="admin-content" style={{ maxWidth: '640px' }}>
          <h2 style={{ margin: '0 0 16px 0', fontSize: '1.3rem', color: '#e0e7ff' }}>
            Broadcast & Target Notifications
          </h2>
          <p style={{ color: '#94a3b8', fontSize: '0.9rem', marginBottom: '24px' }}>
            Scheduled notifications are written to the <code style={{ color: '#38bdf8' }}>scheduled_notifications</code> Firestore collection and dispatched by the cloud scheduler.
          </p>

          <form onSubmit={handleSendNotification} className="admin-form">
            <div className="form-group">
              <label>Target Audience</label>
              <select
                value={formData.targetUid}
                onChange={(e) => setFormData({ ...formData, targetUid: e.target.value })}
              >
                <option value="all">Broadcast to All Users ({users.length} active devices)</option>
                {users.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.email || u.name || 'Anonymous User'} ({u.id.substring(0, 8)}…) — Bedtime: {u.bedtime || 'N/A'}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label>Notification Title</label>
              <input
                type="text"
                required
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="e.g. 🌙 Wind Down Time"
              />
            </div>

            <div className="form-group">
              <label>Notification Body</label>
              <textarea
                required
                rows={3}
                value={formData.body}
                onChange={(e) => setFormData({ ...formData, body: e.target.value })}
                placeholder="e.g. Your bedtime is in 30 minutes. Turn on your sleep tracker now."
              />
            </div>

            <div className="form-group">
              <label>Dispatch Schedule</label>
              <select
                value={formData.scheduleType}
                onChange={(e) => setFormData({ ...formData, scheduleType: e.target.value })}
              >
                <option value="now">Immediate Dispatch (Send Now)</option>
                <option value="timer">Custom Timer Delay</option>
                <option value="bedtime">Relative to User's Bedtime</option>
              </select>
            </div>

            {formData.scheduleType === 'timer' && (
              <div className="form-group">
                <label>Delay in Minutes</label>
                <input
                  type="number"
                  min="1"
                  max="1440"
                  value={formData.timerMinutes}
                  onChange={(e) => setFormData({ ...formData, timerMinutes: e.target.value })}
                />
              </div>
            )}

            {formData.scheduleType === 'bedtime' && (
              <div className="form-group">
                <label>Minutes Relative to Bedtime</label>
                <div className="help-text">Negative is before bedtime (e.g. -60 for 1h before), 0 is exact bedtime.</div>
                <input
                  type="number"
                  value={formData.bedtimeOffset}
                  onChange={(e) => setFormData({ ...formData, bedtimeOffset: e.target.value })}
                />
              </div>
            )}

            <button type="submit" disabled={sendingNotif} className="submit-btn">
              {sendingNotif ? 'Scheduling...' : 'Schedule & Dispatch Notification'}
            </button>

            {notifFeedback.msg && (
              <div className={`form-message ${notifFeedback.type}`}>
                {notifFeedback.msg}
              </div>
            )}
          </form>
        </div>
      )}

      {/* ── TAB 2: Admin Team (Email Whitelist) ── */}
      {activeTab === 'admin_team' && (
        <div className="admin-content" style={{ maxWidth: '850px' }}>
          <h2 style={{ margin: '0 0 8px 0', fontSize: '1.3rem', color: '#e0e7ff' }}>
            Delegate Admin Privileges by Email
          </h2>
          <p style={{ color: '#94a3b8', fontSize: '0.9rem', marginBottom: '24px' }}>
            Add colleague emails below. When they open <code style={{ color: '#38bdf8' }}>{window.location.origin}/admin</code> and click <strong>"Sign in with Google"</strong>, Firestore validates their email and immediately grants them access to work as an administrator.
          </p>

          <form onSubmit={handleAddAdminByEmail} style={{ display: 'flex', gap: '12px', marginBottom: '24px', flexWrap: 'wrap' }}>
            <input
              type="email"
              required
              value={newAdminEmail}
              onChange={(e) => setNewAdminEmail(e.target.value)}
              placeholder="Enter colleague's Google email (e.g. doctor@sleepastra.com)"
              style={{
                flex: '1', minWidth: '280px', padding: '12px 16px', background: 'rgba(10,14,26,0.7)',
                border: '1px solid rgba(255,255,255,0.15)', borderRadius: '10px', color: 'white', fontSize: '0.95rem'
              }}
            />
            <button
              type="submit"
              disabled={adminTeamLoading}
              className="submit-btn"
              style={{ width: 'auto', padding: '12px 24px' }}
            >
              {adminTeamLoading ? 'Authorizing...' : '+ Authorize Admin Email'}
            </button>
          </form>

          {adminTeamFeedback.msg && (
            <div className={`form-message ${adminTeamFeedback.type}`} style={{ marginBottom: '24px' }}>
              {adminTeamFeedback.msg}
            </div>
          )}

          <h3 style={{ fontSize: '1.05rem', margin: '24px 0 12px 0', color: '#cbd5e1' }}>
            Authorized Admin Whitelist ({adminWhitelist.length})
          </h3>

          <div className="admin-table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Admin Email</th>
                  <th>Status</th>
                  <th>Authorized By</th>
                  <th>Date Added</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {adminWhitelist.length === 0 ? (
                  <tr>
                    <td colSpan="5" style={{ textAlign: 'center', color: '#94a3b8', padding: '24px' }}>
                      No separate admin whitelist records found in Firestore. Add an email above to get started.
                    </td>
                  </tr>
                ) : (
                  adminWhitelist.map((adm) => {
                    const isSelf = adm.email === user.email || adm.id === user.email;
                    const isActive = adm.active !== false;
                    const email = adm.email || adm.id;

                    return (
                      <tr key={adm.id}>
                        <td>
                          <strong>{email}</strong>
                          {isSelf && <span style={{ color: '#818cf8', marginLeft: '8px', fontSize: '0.75rem' }}>(You)</span>}
                        </td>
                        <td>
                          <span className={`role-badge ${isActive ? 'role-admin' : 'role-user'}`}>
                            {isActive ? 'Active Admin' : 'Revoked'}
                          </span>
                        </td>
                        <td style={{ color: '#94a3b8', fontSize: '0.85rem' }}>
                          {adm.addedBy || 'System / Direct'}
                        </td>
                        <td style={{ color: '#94a3b8', fontSize: '0.85rem' }}>
                          {adm.addedAt?.toDate ? adm.addedAt.toDate().toLocaleDateString() : 'N/A'}
                        </td>
                        <td>
                          {!isSelf && (
                            <button
                              type="button"
                              className={`role-btn ${isActive ? 'role-btn-revoke' : 'role-btn-grant'}`}
                              onClick={() => handleToggleAdminStatus(adm)}
                              disabled={adminTeamLoading}
                            >
                              {isActive ? 'Revoke Access' : 'Re-activate'}
                            </button>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── TAB 3: User Directory ── */}
      {activeTab === 'users' && (
        <div className="admin-content">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', flexWrap: 'wrap', gap: '12px' }}>
            <div>
              <h2 style={{ margin: 0, fontSize: '1.3rem', color: '#e0e7ff' }}>
                All Registered Users
              </h2>
              <p style={{ color: '#94a3b8', fontSize: '0.85rem', margin: '4px 0 0 0' }}>
                View all Firestore users across <code style={{ color: '#38bdf8' }}>users</code> and <code style={{ color: '#38bdf8' }}>profiles_by_email</code>
              </p>
            </div>

            <input
              type="text"
              className="admin-search-input"
              value={userSearch}
              onChange={(e) => setUserSearch(e.target.value)}
              placeholder="Search by email or UID..."
            />
          </div>

          <div className="admin-table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>User / Email</th>
                  <th>UID</th>
                  <th>Bedtime</th>
                  <th>FCM Token</th>
                  <th>Current Role</th>
                  <th>Modify Role</th>
                </tr>
              </thead>
              <tbody>
                {allUsers
                  .filter((u) => {
                    if (!userSearch) return true;
                    const s = userSearch.toLowerCase();
                    return (
                      (u.email && u.email.toLowerCase().includes(s)) ||
                      (u.id && u.id.toLowerCase().includes(s))
                    );
                  })
                  .map((u) => {
                    const isSelf = u.id === user.uid || (u.email && u.email.toLowerCase() === user.email.toLowerCase());
                    const isUserAdmin = u.role === 'admin';

                    return (
                      <tr key={u.id}>
                        <td>
                          <strong>{u.email || u.name || 'Anonymous User'}</strong>
                        </td>
                        <td style={{ fontFamily: 'monospace', fontSize: '0.8rem', color: '#94a3b8' }}>
                          {u.id.substring(0, 10)}…
                        </td>
                        <td style={{ fontSize: '0.85rem' }}>{u.bedtime || 'N/A'}</td>
                        <td>
                          <span style={{ color: u.fcmToken ? '#4ade80' : '#64748b', fontSize: '0.8rem' }}>
                            {u.fcmToken ? '✅ Registered' : '❌ None'}
                          </span>
                        </td>
                        <td>
                          <span className={`role-badge ${isUserAdmin ? 'role-admin' : 'role-user'}`}>
                            {u.role || 'user'}
                          </span>
                        </td>
                        <td>
                          {isSelf ? (
                            <span style={{ color: '#818cf8', fontSize: '0.8rem' }}>(Your Account)</span>
                          ) : isUserAdmin ? (
                            <button
                              type="button"
                              className="role-btn role-btn-revoke"
                              onClick={() => handleSetUserRole(u.id, 'user')}
                            >
                              Revoke Admin
                            </button>
                          ) : (
                            <button
                              type="button"
                              className="role-btn role-btn-grant"
                              onClick={() => handleSetUserRole(u.id, 'admin')}
                            >
                              Make Admin
                            </button>
                          )}
                        </td>
                      </tr>
                    );
                  })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── TAB 4: Real-time Activity Audit Logs ── */}
      {activeTab === 'audit_logs' && (
        <div className="admin-content">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', flexWrap: 'wrap', gap: '12px' }}>
            <div>
              <h2 style={{ margin: 0, fontSize: '1.3rem', color: '#e0e7ff' }}>
                Real-Time Activity Audit Logs
              </h2>
              <p style={{ color: '#94a3b8', fontSize: '0.85rem', margin: '4px 0 0 0' }}>
                Every admin sign-in, permission delegation, and notification is recorded in <code style={{ color: '#38bdf8' }}>admin_logs</code>
              </p>
            </div>

            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              <select
                value={logFilterAction}
                onChange={(e) => setLogFilterAction(e.target.value)}
                style={{
                  padding: '8px 12px', background: 'rgba(10,14,26,0.6)', border: '1px solid rgba(255,255,255,0.1)',
                  borderRadius: '8px', color: 'white', fontSize: '0.85rem'
                }}
              >
                <option value="ALL">All Actions</option>
                <option value="LOGIN">Logins & Sessions</option>
                <option value="ADMINS">Admin Grants & Revokes</option>
                <option value="NOTIF">Notifications</option>
                <option value="SECURITY">Security / Unauthorized</option>
              </select>

              <input
                type="text"
                className="admin-search-input"
                style={{ maxWidth: '240px' }}
                value={logSearch}
                onChange={(e) => setLogSearch(e.target.value)}
                placeholder="Search logs..."
              />
            </div>
          </div>

          <div className="admin-table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Timestamp</th>
                  <th>Action</th>
                  <th>Admin Email</th>
                  <th>Details</th>
                  <th>Target</th>
                </tr>
              </thead>
              <tbody>
                {filteredLogs.length === 0 ? (
                  <tr>
                    <td colSpan="5" style={{ textAlign: 'center', color: '#94a3b8', padding: '28px' }}>
                      No audit logs match your search.
                    </td>
                  </tr>
                ) : (
                  filteredLogs.map((log) => {
                    const dateStr = log.timestamp?.toDate
                      ? log.timestamp.toDate().toLocaleString()
                      : (log.createdAt ? new Date(log.createdAt).toLocaleString() : 'Just now');

                    return (
                      <tr key={log.id}>
                        <td style={{ fontSize: '0.8rem', color: '#94a3b8', whiteSpace: 'nowrap' }}>
                          {dateStr}
                        </td>
                        <td>
                          <span className={`log-badge ${getBadgeClass(log.action)}`}>
                            {log.action}
                          </span>
                        </td>
                        <td style={{ fontSize: '0.85rem' }}>
                          <strong>{log.adminEmail}</strong>
                        </td>
                        <td style={{ fontSize: '0.85rem', color: '#cbd5e1' }}>
                          {log.details}
                        </td>
                        <td style={{ fontSize: '0.8rem', fontFamily: 'monospace', color: '#38bdf8' }}>
                          {log.target || '—'}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
