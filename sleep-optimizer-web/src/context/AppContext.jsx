import React, { createContext, useContext, useState, useEffect } from 'react';

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

  const updateProfile = (updates) => setProfile(prev => ({ ...prev, ...updates }));

  const goToMain = () => {
    setScreen('main');
    setActiveTab('home');
  };

  const navigateTo = (tab) => {
    setActiveTab(tab);
    setScreen('main');
  };

  return (
    <AppContext.Provider value={{
      screen, setScreen,
      activeTab, setActiveTab,
      isNidraOpen, setNidraOpen,
      onboardingStep, setOnboardingStep,
      profile, updateProfile,
      sleepSessions,
      breathingStreak, setBreathingStreak,
      breathingProgress, setBreathingProgress,
      goToMain, navigateTo,
    }}>
      {children}
    </AppContext.Provider>
  );
}
