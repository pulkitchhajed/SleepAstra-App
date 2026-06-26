import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { useApp } from '../../context/AppContext.jsx';
import './ProfileTab.css';

const SETTINGS = [
  { id: 'account', icon: '👤', label: 'Account Settings', sub: 'Email, password, security' },
  { id: 'notifications', icon: '🔔', label: 'Notifications', sub: 'Reminders & alerts' },
  { id: 'export', icon: '📤', label: 'Export Health Data', sub: 'Download your sleep reports' },
  { id: 'privacy', icon: '🔒', label: 'Privacy & Data', sub: 'Manage data sharing' },
  { id: 'about', icon: 'ℹ️', label: 'About Sleep Optimizer', sub: 'v1.0.0 · Made with ❤️' },
];

export default function ProfileTab() {
  const { profile, updateProfile, breathingStreak, sleepSessions } = useApp();
  const [sleepGoal, setSleepGoal] = useState(profile.sleepGoal || 8);

  const avgScore = sleepSessions.length > 0 
    ? Math.round(sleepSessions.reduce((a, s) => a + s.score, 0) / sleepSessions.length)
    : '--';

  const formatGoal = (h) => {
    const hrs = Math.floor(h);
    const mins = Math.round((h - hrs) * 60);
    return mins > 0 ? `${hrs}h ${mins}m` : `${hrs}h`;
  };

  return (
    <div className="profile-tab">
      {/* Hero */}
      <div className="profile-hero">
        <div className="profile-hero-orb" />
        <motion.div
          className="profile-avatar-ring"
          animate={{ boxShadow: ['0 0 20px rgba(99,102,241,0.4)', '0 0 40px rgba(99,102,241,0.7)', '0 0 20px rgba(99,102,241,0.4)'] }}
          transition={{ duration: 3, repeat: Infinity }}
        >
          <div className="profile-avatar-inner">
            {(profile.name || 'S')[0].toUpperCase()}
          </div>
        </motion.div>
        <h2 className="profile-name">{profile.name || 'Sleep Champion'}</h2>
        <p className="profile-email">{profile.email || 'sleep@optimizer.app'}</p>

        <div className="profile-badges">
          <div className="profile-badge">
            <span style={{ color: '#f97316', fontSize: '1.2rem' }}>🔥</span>
            <span style={{ fontFamily: 'Outfit', fontSize: '1.3rem', fontWeight: 800, color: '#f0f0ff' }}>{breathingStreak}</span>
            <span style={{ fontSize: '0.72rem', color: '#a5b4fc' }}>Day Streak</span>
          </div>
          <div className="profile-badge-divider" />
          <div className="profile-badge">
            <span style={{ color: '#6366f1', fontSize: '1.2rem' }}>⭐</span>
            <span style={{ fontFamily: 'Outfit', fontSize: '1.3rem', fontWeight: 800, color: '#f0f0ff' }}>{avgScore}</span>
            <span style={{ fontSize: '0.72rem', color: '#a5b4fc' }}>Avg Score</span>
          </div>
          <div className="profile-badge-divider" />
          <div className="profile-badge">
            <span style={{ color: '#34d399', fontSize: '1.2rem' }}>📅</span>
            <span style={{ fontFamily: 'Outfit', fontSize: '1.3rem', fontWeight: 800, color: '#f0f0ff' }}>{sleepSessions.length}</span>
            <span style={{ fontSize: '0.72rem', color: '#a5b4fc' }}>Sessions</span>
          </div>
        </div>
      </div>

      {/* Sleep Goal Slider */}
      <div style={{ padding: '0 20px' }}>
        <div className="glass-card" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <div>
              <h4 style={{ fontFamily: 'Outfit', fontWeight: 700 }}>🎯 Sleep Goal</h4>
              <p style={{ fontSize: '0.8rem', color: '#a5b4fc', marginTop: 3 }}>Set your target sleep duration</p>
            </div>
            <div style={{ background: 'rgba(99,102,241,0.15)', border: '1px solid rgba(99,102,241,0.3)', borderRadius: 12, padding: '8px 14px', textAlign: 'center' }}>
              <span style={{ fontFamily: 'Outfit', fontSize: '1.4rem', fontWeight: 800, color: '#818cf8' }}>{formatGoal(sleepGoal)}</span>
            </div>
          </div>
          <input
            id="slider-sleep-goal"
            type="range"
            min={5}
            max={12}
            step={0.5}
            value={sleepGoal}
            onChange={e => { setSleepGoal(Number(e.target.value)); updateProfile({ sleepGoal: Number(e.target.value) }); }}
          />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
            <span style={{ fontSize: '0.72rem', color: '#6b7280' }}>5h</span>
            <span style={{ fontSize: '0.72rem', color: '#6b7280' }}>12h</span>
          </div>
          <div style={{ marginTop: 14, padding: '10px 14px', background: 'rgba(99,102,241,0.08)', borderRadius: 10 }}>
            <p style={{ fontSize: '0.8rem', color: '#a5b4fc' }}>
              {sleepGoal >= 8 ? '✅ Excellent! 8+ hours supports full cognitive recovery.' :
               sleepGoal >= 7 ? '👍 Good. Most adults need 7-9 hours for optimal health.' :
               '⚠️ Less than 7 hours may impact memory and mood.'}
            </p>
          </div>
        </div>
      </div>

      {/* STOP-BANG Summary */}
      {profile.stopBang && (
        <div style={{ padding: '0 20px' }}>
          <div className="glass-card-sm" style={{ padding: '16px 20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h4 style={{ fontFamily: 'Outfit', fontWeight: 700, fontSize: '0.95rem' }}>🩺 STOP-BANG Result</h4>
                <p style={{ fontSize: '0.78rem', color: '#a5b4fc', marginTop: 3 }}>Sleep apnea risk screening</p>
              </div>
              {(() => {
                const score = Object.values(profile.stopBang).filter(Boolean).length;
                const color = score <= 2 ? '#34d399' : score <= 4 ? '#f97316' : '#f87171';
                const label = score <= 2 ? 'Low Risk' : score <= 4 ? 'Moderate' : 'High Risk';
                return (
                  <div style={{ textAlign: 'right' }}>
                    <span style={{ fontFamily: 'Outfit', fontSize: '1.5rem', fontWeight: 900, color }}>{score}/8</span>
                    <p style={{ fontSize: '0.72rem', color, marginTop: 2 }}>{label}</p>
                  </div>
                );
              })()}
            </div>
          </div>
        </div>
      )}

      {/* Settings */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">Settings</h3>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {SETTINGS.map(s => (
            <button key={s.id} id={`setting-${s.id}`} className="setting-item glass-card-sm">
              <span style={{ fontSize: '1.3rem' }}>{s.icon}</span>
              <div style={{ flex: 1, textAlign: 'left' }}>
                <p style={{ fontWeight: 600, color: '#f0f0ff', fontSize: '0.9rem' }}>{s.label}</p>
                <p style={{ fontSize: '0.76rem', color: '#6b7280', marginTop: 2 }}>{s.sub}</p>
              </div>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#4b5563" strokeWidth="2">
                <path d="M9 18l6-6-6-6"/>
              </svg>
            </button>
          ))}
        </div>
      </div>

      {/* Sign Out */}
      <div style={{ padding: '0 20px 20px' }}>
        <button id="btn-sign-out" className="btn-ghost" style={{ width: '100%', color: '#f87171', borderColor: 'rgba(248,113,113,0.2)' }}>
          Sign Out
        </button>
      </div>
    </div>
  );
}
