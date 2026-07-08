import React, { useEffect, useState } from 'react';
import { AppProvider, useApp } from './context/AppContext.jsx';
import SplashScreen from './screens/SplashScreen.jsx';
import WelcomeScreen from './screens/WelcomeScreen.jsx';
import OnboardingFlow from './screens/onboarding/OnboardingFlow.jsx';
import MainShell from './screens/main/MainShell.jsx';
import AdminDashboard from './screens/admin/AdminDashboard.jsx';
import { AnimatePresence, motion } from 'framer-motion';
import './App.css';

function AppRouter() {
  const { screen } = useApp();

  // Hidden admin route bypasses the main app router
  if (window.location.pathname === '/admin') {
    return <AdminDashboard />;
  }

  return (
    <div className="app-root">
      <div className="bg-orb bg-orb-1" />
      <div className="bg-orb bg-orb-2" />
      <div className="bg-orb bg-orb-3" />
      <AnimatePresence mode="wait">
        {screen === 'splash' && (
          <motion.div key="splash" initial={{ opacity: 1 }} exit={{ opacity: 0, transition: { duration: 0.6 } }} style={{ position: 'fixed', inset: 0, zIndex: 200 }}>
            <SplashScreen />
          </motion.div>
        )}
        {screen === 'welcome' && (
          <motion.div key="welcome" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.5 }} style={{ position: 'fixed', inset: 0, zIndex: 150 }}>
            <WelcomeScreen />
          </motion.div>
        )}
        {screen === 'onboarding' && (
          <motion.div key="onboarding" initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.4 }} style={{ position: 'fixed', inset: 0, zIndex: 100 }}>
            <OnboardingFlow />
          </motion.div>
        )}
        {screen === 'main' && (
          <motion.div key="main" initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.5 }} style={{ position: 'fixed', inset: 0, zIndex: 50 }}>
            <MainShell />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function App() {
  return (
    <AppProvider>
      <AppRouter />
    </AppProvider>
  );
}
