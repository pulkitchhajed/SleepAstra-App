import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useApp } from '../../context/AppContext.jsx';
import BottomNav from '../../components/BottomNav.jsx';
import HomeTab from '../tabs/HomeTab.jsx';
import InsightsTab from '../tabs/InsightsTab.jsx';
import SoundsTab from '../tabs/SoundsTab.jsx';
import NidraTab from '../tabs/NidraTab.jsx';
import ProfileTab from '../tabs/ProfileTab.jsx';
import BreathingExercise from '../BreathingExercise.jsx';
import SleepSession from '../SleepSession.jsx';
import './MainShell.css';

export default function MainShell() {
  const { activeTab, isNidraOpen, setNidraOpen } = useApp();
  const [subScreen, setSubScreen] = useState(null); // 'breathing' | 'sleep-session'

  const TABS = { home: HomeTab, insights: InsightsTab, sounds: SoundsTab, profile: ProfileTab };
  const TabComponent = TABS[activeTab] || HomeTab;

  if (subScreen === 'breathing') return <BreathingExercise onBack={() => setSubScreen(null)} />;
  if (subScreen === 'sleep-session') return <SleepSession onBack={() => setSubScreen(null)} />;

  return (
    <div className="main-shell">
      <div className="bg-orb bg-orb-1" />
      <div className="bg-orb bg-orb-2" />
      <div className="bg-orb bg-orb-3" />

      <div className="main-page">
        <AnimatePresence mode="wait">
          <motion.div key={activeTab}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            transition={{ duration: 0.25 }}
            style={{ height: '100%' }}
          >
            <TabComponent onNavigate={setSubScreen} />
          </motion.div>
        </AnimatePresence>
      </div>

      <BottomNav />

      {/* Floating Nidra Button */}
      {!isNidraOpen && (
        <motion.button
          className="nidra-fab"
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={() => setNidraOpen(true)}
          id="btn-nidra-fab"
        >
          <img src="/Nidra.png" alt="Nidra AI" style={{ width: 32, height: 32, objectFit: 'contain', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.3))' }} />
        </motion.button>
      )}

      {/* Nidra Overlay */}
      <AnimatePresence>
        {isNidraOpen && (
          <motion.div
            key="nidra-overlay"
            initial={{ opacity: 0, y: 100 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 100 }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            className="nidra-overlay"
          >
            <NidraTab />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
