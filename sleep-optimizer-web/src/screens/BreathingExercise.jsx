import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useApp } from '../context/AppContext.jsx';
import './BreathingExercise.css';

const PHASES = [
  { label: 'Inhale', duration: 4, scale: 1.45, color: '#6366f1', sub: 'Breathe in slowly through your nose' },
  { label: 'Hold', duration: 4, scale: 1.45, color: '#3b82f6', sub: 'Hold gently, stay relaxed' },
  { label: 'Exhale', duration: 4, scale: 1.0, color: '#34d399', sub: 'Breathe out slowly through your mouth' },
];

const PARTICLE_COUNT = 18;

export default function BreathingExercise({ onBack }) {
  const { breathingStreak, breathingProgress, setBreathingProgress } = useApp();
  const [phaseIdx, setPhaseIdx] = useState(0);
  const [countdown, setCountdown] = useState(PHASES[0].duration);
  const [cycles, setCycles] = useState(0);
  const [running, setRunning] = useState(false);
  const [done, setDone] = useState(false);
  const TARGET_CYCLES = 5;
  const timerRef = useRef(null);

  const particles = useRef(Array.from({ length: PARTICLE_COUNT }, (_, i) => ({
    id: i,
    x: 10 + Math.random() * 80,
    delay: Math.random() * 8,
    duration: 6 + Math.random() * 8,
    size: 3 + Math.random() * 5,
    opacity: 0.2 + Math.random() * 0.5,
  }))).current;

  useEffect(() => {
    if (!running) return;
    timerRef.current = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          setPhaseIdx(pi => {
            const next = (pi + 1) % PHASES.length;
            if (next === 0) {
              setCycles(c => {
                if (c + 1 >= TARGET_CYCLES) {
                  clearInterval(timerRef.current);
                  setRunning(false);
                  setDone(true);
                  setBreathingProgress(p => Math.min(p + 1, 5));
                }
                return c + 1;
              });
            }
            return next;
          });
          return PHASES[(phaseIdx + 1) % PHASES.length].duration;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timerRef.current);
  }, [running, phaseIdx]);

  const phase = PHASES[phaseIdx];

  if (done) {
    return (
      <div className="breathing-root">
        <motion.div className="breathing-done"
          initial={{ opacity: 0, scale: 0.8 }} animate={{ opacity: 1, scale: 1 }} transition={{ type: 'spring', stiffness: 200 }}>
          <motion.div
            initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: 0.2, type: 'spring', stiffness: 300 }}
            style={{ fontSize: '5rem', marginBottom: 20, filter: 'drop-shadow(0 0 30px rgba(52,211,153,0.7))' }}>
            ✅
          </motion.div>
          <h2 style={{ fontFamily: 'Outfit', fontSize: '2rem', fontWeight: 800, color: '#34d399' }}>Session Complete!</h2>
          <p style={{ color: '#a5b4fc', marginTop: 10, lineHeight: 1.7 }}>
            You completed {TARGET_CYCLES} breathing cycles.<br />Your body is ready for deep sleep.
          </p>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 20,
            background: 'rgba(249,115,22,0.12)', border: '1px solid rgba(249,115,22,0.3)',
            borderRadius: 99, padding: '10px 20px' }}>
            <span style={{ fontSize: '1.3rem' }}>🔥</span>
            <span style={{ fontWeight: 700, color: '#f97316' }}>{breathingStreak} Day Streak Maintained!</span>
          </div>
          <button id="btn-breathing-done" className="btn-primary" style={{ marginTop: 32, padding: '16px 40px' }} onClick={onBack}>
            Return Home 🏠
          </button>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="breathing-root">
      {/* Particles */}
      {particles.map(p => (
        <motion.div
          key={p.id}
          className="breathing-particle"
          style={{ left: `${p.x}%`, width: p.size, height: p.size, opacity: p.opacity }}
          animate={{ y: [0, -window.innerHeight - 100] }}
          transition={{ duration: p.duration, delay: p.delay, repeat: Infinity, ease: 'linear' }}
        />
      ))}

      {/* Header */}
      <div className="breathing-header">
        <button id="btn-breathing-back" className="ob-back-btn" onClick={onBack}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M19 12H5M12 5l-7 7 7 7"/>
          </svg>
        </button>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8,
          background: 'rgba(249,115,22,0.12)', border: '1px solid rgba(249,115,22,0.25)',
          borderRadius: 20, padding: '6px 14px' }}>
          <span>🔥</span>
          <span style={{ fontSize: '0.85rem', fontWeight: 700, color: '#f97316' }}>{breathingStreak} Day</span>
        </div>
      </div>

      {/* Center */}
      <div className="breathing-center">
        <p style={{ color: '#a5b4fc', fontSize: '0.85rem', marginBottom: 40 }}>
          Cycle {cycles + 1} of {TARGET_CYCLES}
        </p>

        {/* Ring */}
        <div className="breathing-ring-wrap">
          <motion.div
            className="breathing-ring-outer"
            animate={{ scale: running ? phase.scale : 1, boxShadow: running ? `0 0 60px ${phase.color}60, 0 0 120px ${phase.color}30` : '0 0 20px rgba(99,102,241,0.3)' }}
            transition={{ duration: phase.duration, ease: running ? (phaseIdx === 2 ? 'easeIn' : 'easeOut') : 'easeOut' }}
            style={{ borderColor: running ? phase.color : 'rgba(99,102,241,0.4)' }}
          >
            <motion.div
              className="breathing-ring-inner"
              animate={{ scale: running ? (phaseIdx === 0 ? 1.15 : phaseIdx === 1 ? 1.15 : 1) : 1 }}
              transition={{ duration: phase.duration, ease: 'easeInOut' }}
              style={{ background: `radial-gradient(circle, ${phase.color}25, transparent 70%)` }}
            >
              <span style={{ fontFamily: 'Outfit', fontSize: '3rem', fontWeight: 900, color: running ? phase.color : '#6366f1' }}>
                {countdown}
              </span>
            </motion.div>
          </motion.div>

          {/* Orbit dots */}
          {running && [0, 1, 2, 3].map(i => (
            <motion.div key={i} className="orbit-dot"
              style={{ background: phase.color }}
              animate={{ rotate: 360 }}
              transition={{ duration: 3, repeat: Infinity, ease: 'linear', delay: i * 0.75 }}
            />
          ))}
        </div>

        <motion.h3
          key={phase.label}
          initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}
          style={{ fontFamily: 'Outfit', fontSize: '2rem', fontWeight: 800, color: phase.color, marginTop: 32 }}>
          {phase.label}
        </motion.h3>
        <p style={{ color: '#a5b4fc', fontSize: '0.9rem', marginTop: 8, textAlign: 'center', maxWidth: 260 }}>
          {phase.sub}
        </p>

        {/* Phase indicators */}
        <div style={{ display: 'flex', gap: 8, marginTop: 32 }}>
          {PHASES.map((p, i) => (
            <div key={i} style={{
              height: 4, width: i === phaseIdx ? 32 : 12, borderRadius: 99,
              background: i === phaseIdx ? p.color : 'rgba(165,180,252,0.2)',
              transition: 'all 0.3s',
            }} />
          ))}
        </div>
      </div>

      {/* Start/Pause */}
      <div style={{ padding: '0 24px 40px', width: '100%' }}>
        <button
          id="btn-breathing-toggle"
          className="btn-primary"
          style={{ width: '100%', padding: '18px', fontSize: '1.05rem' }}
          onClick={() => setRunning(!running)}
        >
          {running ? '⏸ Pause' : cycles === 0 ? '🫁 Start Breathing' : '▶ Resume'}
        </button>
      </div>
    </div>
  );
}
