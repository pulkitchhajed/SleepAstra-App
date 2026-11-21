import React, { createContext, useContext, useState, useEffect, useRef } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import { auth } from '../firebaseConfig';
import {
  getEffectiveUid,
  saveUserProfile,
  fetchUserProfile,
  saveSleepReport,
  fetchSleepReports,
  saveBreathingSession,
  saveNidraMessage,
  fetchNidraMessages,
  authSignIn,
  authSignUp,
  authSignInGuest,
  authSignOut,
} from '../services/dbService';

const AppContext = createContext(null);

export const useApp = () => useContext(AppContext);

const defaultProfile = {
  name: '',
  email: '',
  dob: '',
  gender: '',
  goals: [],
  stopBang: { s: false, t: false, o: false, p: false, b: false, a: false, n: false, g: false },
  lifestyle: { caffeine: 'moderate', exercise: 'sometimes', screenTime: '1-2h' },
  sleepGoal: 8,
  streak: 5,
};

export function AppProvider({ children }) {
  const [screen, setScreen] = useState('splash'); // splash | welcome | onboarding | main
  const [activeTab, setActiveTab] = useState('home');
  const [isNidraOpen, setNidraOpen] = useState(false);
  const [onboardingStep, setOnboardingStep] = useState(0);
  const [profile, setProfile] = useState(defaultProfile);
  const [sleepSessions, setSleepSessions] = useState([]);
  const [breathingStreak, setBreathingStreak] = useState(5);
  const [breathingProgress, setBreathingProgress] = useState(2);
  const [currentUser, setCurrentUser] = useState(null);
  const [currentUid, setCurrentUid] = useState(getEffectiveUid(null));
  const [activeSleepConfig, setActiveSleepConfig] = useState({
    mood: 'good',
    alarmTime: '07:00',
    sound: null,
    vibration: true,
  });

  const profileRef = useRef(profile);
  useEffect(() => {
    profileRef.current = profile;
  }, [profile]);

  // Auth state listener & automatic Firestore data synchronization
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setCurrentUser(user);
      const uid = getEffectiveUid(user);
      setCurrentUid(uid);

      if (user || uid) {
        try {
          // 1. Fetch user profile from Firestore
          const firestoreProfile = await fetchUserProfile(uid, user?.email);
          if (firestoreProfile) {
            setProfile((prev) => ({
              ...prev,
              ...firestoreProfile,
              dob: firestoreProfile.dateOfBirth || firestoreProfile.dob || prev.dob,
              goals: firestoreProfile.goals || firestoreProfile.primarySleepGoals || prev.goals,
              streak: firestoreProfile.breathingStreak ?? prev.streak,
            }));
            if (firestoreProfile.breathingStreak !== undefined) {
              setBreathingStreak(firestoreProfile.breathingStreak);
            }
            if (firestoreProfile.breathingProgress !== undefined) {
              setBreathingProgress(firestoreProfile.breathingProgress);
            }
          }

          // 2. Fetch sleep reports from Firestore
          const reports = await fetchSleepReports(uid);
          if (reports && reports.length > 0) {
            const formattedReports = reports.map((r) => ({
              id: r.id,
              score: r.qualityScore || 85,
              quality: r.quality || 'Good',
              durationHours: r.totalDurationMs ? +(r.totalDurationMs / 3600000).toFixed(1) : 7.5,
              date: r.recordedAt?.toDate ? r.recordedAt.toDate() : new Date(Number(r.id) || Date.now()),
              mood: r.mood || 'good',
              ...r,
            }));
            setSleepSessions(formattedReports);
          }
        } catch (err) {
          console.error('Failed to sync Firestore data for user:', err);
        }
      }
    });

    return () => unsubscribe();
  }, []);

  /**
   * Update profile locally and auto-save changes to Firestore
   */
  const updateProfile = (updates, shouldPersist = true) => {
    setProfile((prev) => {
      const next = { ...prev, ...updates };
      if (shouldPersist && (next.onboardingComplete || next.email || next.name)) {
        saveUserProfile(currentUid, next).catch((e) =>
          console.error('Failed to persist profile updates:', e)
        );
      }
      return next;
    });
  };

  /**
   * Save a newly completed sleep session to Firestore & local state
   */
  const recordSleepSession = async (sessionData) => {
    const fullData = {
      ...activeSleepConfig,
      ...sessionData,
      sleepGoal: profile.sleepGoal || 8,
    };
    const saved = await saveSleepReport(currentUid, fullData);
    if (saved) {
      const formatted = {
        id: saved.id,
        score: saved.qualityScore,
        quality: saved.quality,
        durationHours: +(saved.totalDurationMs / 3600000).toFixed(1),
        date: new Date(),
        ...saved,
      };
      setSleepSessions((prev) => [formatted, ...prev]);
    }
    return saved;
  };

  /**
   * Record a completed breathing exercise in Firestore & increment streak
   */
  const recordBreathingSession = async (cycles = 5) => {
    const nextStreak = breathingStreak + 1;
    setBreathingStreak(nextStreak);
    setBreathingProgress(5);
    await saveBreathingSession(currentUid, {
      cycles,
      streak: nextStreak,
      progress: 5,
      durationSeconds: 60,
    });
    updateProfile({ breathingStreak: nextStreak, breathingProgress: 5 });
  };

  /**
   * Sign In with Email & Password
   */
  const loginUser = async (email, password) => {
    const user = await authSignIn(email, password);
    setCurrentUser(user);
    setCurrentUid(user.uid);
    const p = await fetchUserProfile(user.uid, email);
    if (p) setProfile((prev) => ({ ...prev, ...p }));
    const r = await fetchSleepReports(user.uid);
    if (r) setSleepSessions(r);
    goToMain();
    return user;
  };

  /**
   * Register with Email & Password and save complete profile
   */
  const registerUser = async (email, password, extraProfile = {}) => {
    const user = await authSignUp(email, password);
    setCurrentUser(user);
    setCurrentUid(user.uid);
    const fullProfile = {
      ...profileRef.current,
      ...extraProfile,
      email,
      onboardingComplete: true,
    };
    await saveUserProfile(user.uid, fullProfile);
    setProfile(fullProfile);
    goToMain();
    return user;
  };

  /**
   * Continue as Guest
   */
  const continueAsGuest = async () => {
    const guestUser = await authSignInGuest();
    const uid = guestUser.uid;
    setCurrentUser(guestUser);
    setCurrentUid(uid);
    goToMain();
  };

  /**
   * Logout
   */
  const logoutUser = async () => {
    await authSignOut();
    setCurrentUser(null);
    setProfile(defaultProfile);
    setSleepSessions([]);
    setScreen('welcome');
  };

  const goToMain = () => {
    setScreen('main');
    setActiveTab('home');
  };

  const navigateTo = (tab) => {
    setActiveTab(tab);
    setScreen('main');
  };

  return (
    <AppContext.Provider
      value={{
        screen,
        setScreen,
        activeTab,
        setActiveTab,
        isNidraOpen,
        setNidraOpen,
        onboardingStep,
        setOnboardingStep,
        profile,
        updateProfile,
        sleepSessions,
        recordSleepSession,
        breathingStreak,
        setBreathingStreak,
        breathingProgress,
        setBreathingProgress,
        recordBreathingSession,
        currentUser,
        currentUid,
        activeSleepConfig,
        setActiveSleepConfig,
        loginUser,
        registerUser,
        continueAsGuest,
        logoutUser,
        goToMain,
        navigateTo,
      }}
    >
      {children}
    </AppContext.Provider>
  );
}
