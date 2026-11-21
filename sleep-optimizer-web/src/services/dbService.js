import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  addDoc,
  updateDoc,
  query,
  orderBy,
  limit,
  serverTimestamp,
} from 'firebase/firestore';
import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signInAnonymously,
  signOut,
  onAuthStateChanged,
} from 'firebase/auth';
import { db, auth } from '../firebaseConfig';

const DEVICE_UID_KEY = 'sleep_optimizer_device_uid';

/**
 * Generates or retrieves a persistent device-level guest UID
 * (mirrors the Flutter app's device UUID behavior)
 */
export function getOrCreateDeviceUid() {
  if (typeof window === 'undefined') return 'guest_default_uid';
  let uid = localStorage.getItem(DEVICE_UID_KEY);
  if (!uid) {
    uid = 'web_' + (crypto?.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2, 15) + Date.now().toString(36));
    localStorage.setItem(DEVICE_UID_KEY, uid);
  }
  return uid;
}

/**
 * Returns the active UID: authenticated user's UID if logged in, else device UID
 */
export function getEffectiveUid(user) {
  if (user && user.uid) return user.uid;
  return getOrCreateDeviceUid();
}

/**
 * Saves or updates a full user profile to Firestore
 * Writes to both:
 * 1) /users/{uid}
 * 2) /profiles_by_email/{email} (for fast search, admin lookup, and mobile failover)
 */
export async function saveUserProfile(uid, profileData) {
  if (!uid) uid = getOrCreateDeviceUid();
  const normalizedEmail = (profileData.email || '').trim().toLowerCase();

  const stopBangScore = profileData.stopBang
    ? Object.values(profileData.stopBang).filter(Boolean).length
    : (profileData.stopBangScore || 0);

  const stopBangRisk =
    stopBangScore <= 2 ? 'Low' : stopBangScore <= 4 ? 'Moderate' : 'High';

  const docData = {
    name: profileData.name || '',
    email: normalizedEmail,
    dateOfBirth: profileData.dob || profileData.dateOfBirth || '1995-01-01',
    gender: profileData.gender || 'other',
    goals: profileData.goals || [],
    primarySleepGoals: profileData.goals || [],
    stopBang: profileData.stopBang || {},
    stopBangScore,
    stopBangRisk,
    lifestyle: profileData.lifestyle || {
      caffeine: 'moderate',
      exercise: 'sometimes',
      screenTime: '1-2h',
    },
    sleepGoal: Number(profileData.sleepGoal) || 8,
    breathingStreak: Number(profileData.breathingStreak || profileData.streak) || 5,
    breathingProgress: Number(profileData.breathingProgress) || 2,
    role: profileData.role || 'user',
    onboardingComplete: true,
    updatedAt: serverTimestamp(),
  };

  try {
    // 1. Save to primary /users/{uid} document
    const userRef = doc(db, 'users', uid);
    await setDoc(userRef, docData, { merge: true });

    // 2. Mirror to /profiles_by_email/{email} if an email is provided
    if (normalizedEmail) {
      const emailRef = doc(db, 'profiles_by_email', normalizedEmail);
      await setDoc(
        emailRef,
        {
          ...docData,
          lastLinkedUid: uid,
        },
        { merge: true }
      );
    }

    return { success: true, uid };
  } catch (error) {
    console.error('Error saving user profile to Firestore:', error);
    return { success: false, error };
  }
}

/**
 * Fetches a user profile from Firestore by UID with email failover
 */
export async function fetchUserProfile(uid, email = null) {
  if (!uid && !email) return null;
  try {
    if (uid) {
      const userSnap = await getDoc(doc(db, 'users', uid));
      if (userSnap.exists()) {
        return { id: userSnap.id, ...userSnap.data() };
      }
    }

    // Failover: look up in /profiles_by_email/{email}
    if (email) {
      const normalizedEmail = email.trim().toLowerCase();
      const emailSnap = await getDoc(doc(db, 'profiles_by_email', normalizedEmail));
      if (emailSnap.exists()) {
        const data = emailSnap.data();
        // If we have an active UID, sync to /users/{uid}
        if (uid) {
          await setDoc(doc(db, 'users', uid), data, { merge: true });
        }
        return { id: uid || emailSnap.id, ...data };
      }
    }
  } catch (error) {
    console.error('Error fetching user profile from Firestore:', error);
  }
  return null;
}

/**
 * Saves a completed sleep session to Firestore under /users/{uid}/sleep_reports
 */
export async function saveSleepReport(uid, reportData) {
  if (!uid) uid = getOrCreateDeviceUid();
  const docId = Date.now().toString();

  const durationSecs = Number(reportData.durationSeconds) || 0;
  const hours = durationSecs / 3600;
  const targetHours = Number(reportData.sleepGoal) || 8;
  const calculatedScore = Math.min(100, Math.max(50, Math.round((hours / targetHours) * 95)));

  const sessionDoc = {
    fileName: `web_session_${docId}`,
    recordedAt: serverTimestamp(),
    totalDurationMs: durationSecs * 1000,
    snoringDurationMs: (reportData.snoringDurationSeconds || 0) * 1000,
    snoringEventCount: reportData.snoringEventCount || 0,
    qualityScore: reportData.score || calculatedScore,
    quality: reportData.quality || (calculatedScore >= 85 ? 'excellent' : calculatedScore >= 70 ? 'good' : 'fair'),
    mood: reportData.mood || 'good',
    alarmTime: reportData.alarmTime || '07:00',
    soundUsed: reportData.soundUsed || 'None',
    lightSleepPercent: 0.50,
    deepSleepPercent: 0.25,
    remSleepPercent: 0.25,
    sleepDebtHours: Math.max(0, +(targetHours - hours).toFixed(1)),
    createdAt: serverTimestamp(),
  };

  try {
    await setDoc(doc(db, 'users', uid, 'sleep_reports', docId), sessionDoc);

    // Update summary in user's main doc
    await updateDoc(doc(db, 'users', uid), {
      lastSleepScore: sessionDoc.qualityScore,
      lastSleepRecordedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }).catch(() => {});

    return { id: docId, ...sessionDoc };
  } catch (error) {
    console.error('Error saving sleep report to Firestore:', error);
    return null;
  }
}

/**
 * Fetches all sleep reports for a user from Firestore
 */
export async function fetchSleepReports(uid) {
  if (!uid) uid = getOrCreateDeviceUid();
  try {
    const reportsCol = collection(db, 'users', uid, 'sleep_reports');
    const snap = await getDocs(reportsCol);
    const reports = [];
    snap.forEach((d) => reports.push({ id: d.id, ...d.data() }));
    // Sort newest first
    reports.sort((a, b) => {
      const tA = a.recordedAt?.toMillis ? a.recordedAt.toMillis() : (a.id ? Number(a.id) : 0);
      const tB = b.recordedAt?.toMillis ? b.recordedAt.toMillis() : (b.id ? Number(b.id) : 0);
      return tB - tA;
    });
    return reports;
  } catch (error) {
    console.error('Error fetching sleep reports:', error);
    return [];
  }
}

/**
 * Saves a completed breathing exercise session and updates the user's streak in Firestore
 */
export async function saveBreathingSession(uid, sessionData) {
  if (!uid) uid = getOrCreateDeviceUid();
  const docId = Date.now().toString();

  const data = {
    cycles: sessionData.cycles || 5,
    durationSeconds: sessionData.durationSeconds || 60,
    streak: sessionData.streak || 5,
    completedAt: serverTimestamp(),
  };

  try {
    await setDoc(doc(db, 'users', uid, 'breathing_sessions', docId), data);

    // Update streak on user document
    await setDoc(
      doc(db, 'users', uid),
      {
        breathingStreak: data.streak,
        breathingProgress: sessionData.progress || 5,
        lastBreathingAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );

    return true;
  } catch (error) {
    console.error('Error saving breathing session:', error);
    return false;
  }
}

/**
 * Saves a message from the Nidra AI sleep coach conversation to Firestore
 */
export async function saveNidraMessage(uid, message) {
  if (!uid) uid = getOrCreateDeviceUid();
  const docId = message.id ? message.id.toString() : Date.now().toString();
  try {
    await setDoc(doc(db, 'users', uid, 'nidra_messages', docId), {
      role: message.role,
      text: message.text,
      timestamp: serverTimestamp(),
    });
  } catch (error) {
    console.error('Error saving Nidra message:', error);
  }
}

/**
 * Fetches Nidra AI conversation messages from Firestore
 */
export async function fetchNidraMessages(uid) {
  if (!uid) uid = getOrCreateDeviceUid();
  try {
    const snap = await getDocs(collection(db, 'users', uid, 'nidra_messages'));
    const msgs = [];
    snap.forEach((d) => msgs.push({ id: d.id, ...d.data() }));
    msgs.sort((a, b) => Number(a.id) - Number(b.id));
    return msgs;
  } catch (error) {
    console.error('Error fetching Nidra messages:', error);
    return [];
  }
}

/**
 * Authentication Helpers
 */
export async function authSignUp(email, password) {
  const cred = await createUserWithEmailAndPassword(auth, email, password);
  return cred.user;
}

export async function authSignIn(email, password) {
  const cred = await signInWithEmailAndPassword(auth, email, password);
  return cred.user;
}

export async function authSignInGuest() {
  try {
    const cred = await signInAnonymously(auth);
    return cred.user;
  } catch (e) {
    // If anonymous auth is not enabled in Firebase Console, fallback to device UID
    console.warn('Anonymous auth unavailable, using persistent device UID:', e?.message);
    return { uid: getOrCreateDeviceUid(), isAnonymous: true };
  }
}

export async function authSignOut() {
  await signOut(auth);
}
