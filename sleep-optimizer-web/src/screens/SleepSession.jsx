import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import './SleepSession.css';

export default function SleepSession({ onBack }) {
  const [elapsed, setElapsed] = useState(0);
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => {
      setElapsed(e => e + 1);
      setCurrentTime(new Date());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const formatElapsed = (secs) => {
    const h = Math.floor(secs / 3600).toString().padStart(2, '0');
    const m = Math.floor((secs % 3600) / 60).toString().padStart(2, '0');
    const s = (secs % 60).toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  };

  const formatTime = (date) =>
    date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true });

  return (
    <div className="session-root">
      {/* Stars */}
      {Array.from({ length: 40 }, (_, i) => (
        <motion.div
          key={i}
          className="session-star"
          style={{
            left: `${Math.random() * 100}%`,
            top: `${Math.random() * 100}%`,
            width: Math.random() * 3 + 1,
            height: Math.random() * 3 + 1,
          }}
          animate={{ opacity: [0.1, 0.8, 0.1] }}
          transition={{ duration: 2 + Math.random() * 4, repeat: Infinity, delay: Math.random() * 3 }}
        />
      ))}

      <div className="session-content">
        {/* Current time */}
        <motion.div
          initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }}
        >
          <h1 className="session-time">{formatTime(currentTime)}</h1>
          <p className="session-date">{currentTime.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' })}</p>
        </motion.div>

        {/* Moon */}
        <motion.div
          className="session-moon"
          animate={{ y: [-8, 8, -8] }}
          transition={{ duration: 6, repeat: Infinity, ease: 'easeInOut' }}
        >
          🌙
        </motion.div>

        {/* Duration */}
        <motion.div
          className="session-duration-wrap"
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.5 }}
        >
          <p style={{ color: '#a5b4fc', fontSize: '0.8rem', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
            Session Duration
          </p>
          <p className="session-duration">{formatElapsed(elapsed)}</p>
        </motion.div>

        {/* Sound indicator */}
        <motion.div
          className="session-sound-indicator"
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.7 }}
        >
          <div className="sound-wave">
            {[1, 2, 3, 4, 5].map(i => (
              <motion.div
                key={i}
                className="sound-bar"
                animate={{ height: [`${8 + Math.random() * 16}px`, `${20 + Math.random() * 14}px`, `${8 + Math.random() * 16}px`] }}
                transition={{ duration: 0.8 + Math.random() * 0.4, repeat: Infinity, delay: i * 0.12 }}
              />
            ))}
          </div>
          <span style={{ fontSize: '0.82rem', color: '#a5b4fc' }}>🌧️ Deep Rain Playing</span>
        </motion.div>

        {/* Wake Up Button */}
        <motion.div
          initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.9 }}
          style={{ width: '100%' }}
        >
          <button id="btn-wake-up" className="wake-up-btn" onClick={onBack}>
            ☀️ Wake Up
          </button>
          <p style={{ textAlign: 'center', fontSize: '0.75rem', color: '#4b5563', marginTop: 12 }}>
            Hold to end your sleep session
          </p>
        </motion.div>
      </div>
    </div>
  );
}
