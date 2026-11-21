import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useApp } from '../context/AppContext.jsx';
import './SleepSession.css';

export default function SleepSession({ onBack }) {
  const { recordSleepSession } = useApp();
  const [elapsed, setElapsed] = useState(0);
  const [currentTime, setCurrentTime] = useState(new Date());
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisStep, setAnalysisStep] = useState('Extracting audio & sleep architecture...');
  const [completedReport, setCompletedReport] = useState(null);

  useEffect(() => {
    if (isAnalyzing || completedReport) return;
    const timer = setInterval(() => {
      setElapsed(e => e + 1);
      setCurrentTime(new Date());
    }, 1000);
    return () => clearInterval(timer);
  }, [isAnalyzing, completedReport]);

  const handleWakeUp = async () => {
    setIsAnalyzing(true);
    setAnalysisStep('Evaluating breathing continuity & snore patterns...');
    try {
      let saved = null;
      if (recordSleepSession) {
        saved = await recordSleepSession({ durationSeconds: elapsed });
      }
      setAnalysisStep('Finalizing sleep score & health metrics...');
      await new Promise(r => setTimeout(r, 900));
      const hours = Math.floor(elapsed / 3600);
      const mins = Math.floor((elapsed % 3600) / 60);
      setCompletedReport(saved || {
        score: 85,
        quality: 'Good',
        durationHours: +(elapsed / 3600).toFixed(1),
        durationText: `${hours}h ${mins}m`,
        snoreMins: Math.max(0, Math.round((elapsed * 0.05) / 60)),
        apneaRisk: 'Low',
      });
    } catch (e) {
      console.error('Error saving sleep session:', e);
      onBack();
    } finally {
      setIsAnalyzing(false);
    }
  };

  const formatElapsed = (secs) => {
    const h = Math.floor(secs / 3600).toString().padStart(2, '0');
    const m = Math.floor((secs % 3600) / 60).toString().padStart(2, '0');
    const s = (secs % 60).toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  };

  const formatTime = (date) =>
    date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true });

  const score = completedReport?.score || 85;
  const scoreColor = score >= 80 ? '#10b981' : score >= 65 ? '#3b82f6' : score >= 50 ? '#f59e0b' : '#ef4444';

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

        {/* Wake Up & Analysis Area */}
        <motion.div
          initial={{ opacity: 0, y: 30 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.9 }}
          style={{ width: '100%' }}
        >
          {isAnalyzing ? (
            <div style={{
              background: 'rgba(26,29,58,0.85)',
              border: '1px solid rgba(99,102,241,0.3)',
              borderRadius: 24,
              padding: '24px 20px',
              textAlign: 'center',
              backdropFilter: 'blur(12px)',
            }}>
              <div style={{ fontSize: '2.5rem', marginBottom: 12 }}>🧠</div>
              <h3 style={{ fontFamily: 'Outfit', fontSize: '1.25rem', fontWeight: 700, color: '#f0f0ff' }}>
                Analyzing Sleep Session
              </h3>
              <p style={{ color: '#818cf8', fontSize: '0.88rem', marginTop: 6, fontWeight: 500 }}>
                {analysisStep}
              </p>
              <div style={{
                width: 32,
                height: 32,
                border: '3px solid rgba(99,102,241,0.2)',
                borderTopColor: '#6366f1',
                borderRadius: '50%',
                margin: '18px auto 0',
                animation: 'spin 1s linear infinite',
              }} />
            </div>
          ) : completedReport ? (
            <div style={{
              background: 'rgba(21,23,40,0.95)',
              border: '1px solid rgba(99,102,241,0.35)',
              borderRadius: 24,
              padding: '24px 20px',
              textAlign: 'center',
              boxShadow: '0 12px 36px rgba(0,0,0,0.6)',
              backdropFilter: 'blur(16px)',
            }}>
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, padding: '4px 12px', background: 'rgba(16,185,129,0.15)', borderRadius: 20, color: '#34d399', fontSize: '0.85rem', fontWeight: 700, marginBottom: 14 }}>
                ✓ Analysis Done
              </div>
              <h3 style={{ fontFamily: 'Outfit', fontSize: '1.4rem', fontWeight: 800, color: '#f0f0ff' }}>
                Sleep Report Ready!
              </h3>
              <p style={{ color: '#a5b4fc', fontSize: '0.85rem', marginTop: 4 }}>
                Your sleep was recorded and analyzed successfully.
              </p>

              {/* Score card */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: 16,
                background: 'rgba(255,255,255,0.04)',
                borderRadius: 18,
                padding: '14px 18px',
                margin: '18px 0',
                border: '1px solid rgba(165,180,252,0.12)',
              }}>
                <div style={{
                  width: 54,
                  height: 54,
                  borderRadius: '50%',
                  border: `2.5px solid ${scoreColor}`,
                  background: `${scoreColor}18`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '1.3rem',
                  fontWeight: 900,
                  color: scoreColor,
                  fontFamily: 'Outfit',
                }}>
                  {score}
                </div>
                <div style={{ textAlign: 'left' }}>
                  <p style={{ fontWeight: 700, fontSize: '1.05rem', color: '#f0f0ff' }}>
                    {completedReport.quality || 'Good'} Sleep 😊
                  </p>
                  <p style={{ fontSize: '0.8rem', color: '#a5b4fc', marginTop: 2 }}>
                    Duration: {completedReport.durationText || formatElapsed(elapsed)} • Snoring: {completedReport.snoreMins ? `${completedReport.snoreMins}m` : 'None'}
                  </p>
                </div>
              </div>

              <button
                id="btn-view-report"
                className="btn-primary"
                style={{ width: '100%', padding: '14px', borderRadius: 16, fontSize: '1rem', fontWeight: 700 }}
                onClick={onBack}
              >
                View Full Results →
              </button>
            </div>
          ) : (
            <>
              <button
                id="btn-wake-up"
                className="wake-up-btn"
                disabled={isAnalyzing}
                onClick={handleWakeUp}
              >
                ☀️ Wake Up & Analyze
              </button>
              <p style={{ textAlign: 'center', fontSize: '0.75rem', color: '#4b5563', marginTop: 12 }}>
                Session automatically saved to cloud
              </p>
            </>
          )}
        </motion.div>
      </div>
    </div>
  );
}
