import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import { useApp } from '../context/AppContext.jsx';
import './SplashScreen.css';

export default function SplashScreen() {
  const { setScreen } = useApp();

  useEffect(() => {
    const timer = setTimeout(() => setScreen('welcome'), 2800);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div className="splash-root">
      <div className="splash-orb splash-orb-1" />
      <div className="splash-orb splash-orb-2" />

      <motion.div
        className="splash-content"
        initial={{ opacity: 0, scale: 0.85 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.8, ease: [0.34, 1.56, 0.64, 1] }}
      >
        <motion.div
          className="splash-icon-ring"
          animate={{ rotate: 360 }}
          transition={{ duration: 12, ease: 'linear', repeat: Infinity }}
        >
          <div className="splash-ring-track" />
        </motion.div>

        <motion.div
          className="splash-moon"
          initial={{ opacity: 0, scale: 0.5 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.3, duration: 0.6, ease: [0.34, 1.56, 0.64, 1] }}
        >
          🌙
        </motion.div>

        <motion.h1
          className="splash-title"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6, duration: 0.5 }}
        >
          Sleep Optimizer
        </motion.h1>

        <motion.p
          className="splash-subtitle"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.9, duration: 0.5 }}
        >
          Your intelligent sleep companion
        </motion.p>

        <motion.div
          className="splash-dots"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.4 }}
        >
          {[0, 1, 2].map(i => (
            <motion.span
              key={i}
              className="splash-dot"
              animate={{ opacity: [0.3, 1, 0.3] }}
              transition={{ duration: 1.2, delay: i * 0.2, repeat: Infinity }}
            />
          ))}
        </motion.div>
      </motion.div>
    </div>
  );
}
