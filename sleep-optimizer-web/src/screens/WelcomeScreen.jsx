import React from 'react';
import { motion } from 'framer-motion';
import { useApp } from '../context/AppContext.jsx';
import './WelcomeScreen.css';

const stars = Array.from({ length: 30 }, (_, i) => ({
  id: i,
  x: Math.random() * 100,
  y: Math.random() * 100,
  size: Math.random() * 3 + 1,
  delay: Math.random() * 3,
}));

export default function WelcomeScreen() {
  const { setScreen } = useApp();

  return (
    <div className="welcome-root">
      {stars.map(s => (
        <motion.div
          key={s.id}
          className="welcome-star"
          style={{ left: `${s.x}%`, top: `${s.y}%`, width: s.size, height: s.size }}
          animate={{ opacity: [0.2, 1, 0.2] }}
          transition={{ duration: 2 + s.delay, repeat: Infinity, delay: s.delay }}
        />
      ))}

      <div className="welcome-content">
        <motion.div
          initial={{ opacity: 0, y: -30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, ease: 'easeOut' }}
          className="welcome-hero"
        >
          <div className="welcome-moon-wrap">
            <motion.div
              className="welcome-glow-ring"
              animate={{ scale: [1, 1.12, 1], opacity: [0.5, 0.9, 0.5] }}
              transition={{ duration: 3, repeat: Infinity }}
            />
            <span className="welcome-moon">🌙</span>
          </div>
        </motion.div>

        <motion.div
          className="welcome-text"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.6 }}
        >
          <h1 className="welcome-title">Sleep<br /><span className="welcome-highlight">Optimizer</span></h1>
          <p className="welcome-desc">
            Your AI-powered companion for deeper sleep, less snoring, and waking up refreshed.
          </p>
        </motion.div>

        <motion.div
          className="welcome-actions"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6, duration: 0.6 }}
        >
          <button
            id="btn-get-started"
            className="btn-primary welcome-btn-primary"
            onClick={() => setScreen('onboarding')}
          >
            ✨ Get Started
          </button>
          <button
            id="btn-sign-in"
            className="btn-secondary welcome-btn-secondary"
            onClick={() => setScreen('onboarding')}
          >
            Sign In
          </button>
          <button
            id="btn-skip"
            className="btn-ghost"
            onClick={() => setScreen('main')}
          >
            Skip for now →
          </button>
        </motion.div>

        <motion.div
          className="welcome-features"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1, duration: 0.6 }}
        >
          {['🎵 Sleep Sounds', '🤖 AI Coach', '📊 Insights', '🫁 Breathing'].map((f, i) => (
            <div key={i} className="welcome-feature-pill">{f}</div>
          ))}
        </motion.div>
      </div>
    </div>
  );
}
