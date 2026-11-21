import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
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
  const { setScreen, loginUser, continueAsGuest } = useApp();
  const [showSignInModal, setShowSignInModal] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  const handleSignIn = async (e) => {
    e.preventDefault();
    if (!email || !password) return;
    setLoading(true);
    setErrorMsg('');
    try {
      await loginUser(email.trim().toLowerCase(), password);
    } catch (err) {
      console.error('Sign in error:', err);
      setErrorMsg(err.message || 'Failed to sign in. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="welcome-root">
      {stars.map((s) => (
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
          <h1 className="welcome-title">
            Sleep<br />
            <span className="welcome-highlight">Optimizer</span>
          </h1>
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
            onClick={() => setShowSignInModal(true)}
          >
            Sign In
          </button>
          <button
            id="btn-skip"
            className="btn-ghost"
            onClick={continueAsGuest}
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
            <div key={i} className="welcome-feature-pill">
              {f}
            </div>
          ))}
        </motion.div>
      </div>

      {/* Sign In Modal */}
      <AnimatePresence>
        {showSignInModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            style={{
              position: 'fixed',
              inset: 0,
              backgroundColor: 'rgba(0, 0, 0, 0.75)',
              backdropFilter: 'blur(8px)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 300,
              padding: 20,
            }}
          >
            <motion.div
              initial={{ scale: 0.9, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.9, y: 20 }}
              style={{
                width: '100%',
                maxWidth: 420,
                background: '#131528',
                border: '1px solid rgba(165,180,252,0.2)',
                borderRadius: 20,
                padding: 28,
                boxShadow: '0 20px 40px rgba(0,0,0,0.5)',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
                <h3 style={{ fontFamily: 'Outfit', fontSize: '1.4rem', fontWeight: 700, color: '#f0f0ff', margin: 0 }}>
                  Welcome Back 👋
                </h3>
                <button
                  onClick={() => setShowSignInModal(false)}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#8b92b2',
                    fontSize: '1.5rem',
                    cursor: 'pointer',
                  }}
                >
                  ✕
                </button>
              </div>

              <form onSubmit={handleSignIn} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div>
                  <label style={{ fontSize: '0.8rem', color: '#a5b4fc', fontWeight: 600, marginBottom: 6, display: 'block' }}>
                    EMAIL ADDRESS
                  </label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="user@example.com"
                    style={{
                      width: '100%',
                      padding: '12px 16px',
                      background: 'rgba(0,0,0,0.3)',
                      border: '1px solid rgba(165,180,252,0.2)',
                      borderRadius: 10,
                      color: 'white',
                      fontSize: '1rem',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                <div>
                  <label style={{ fontSize: '0.8rem', color: '#a5b4fc', fontWeight: 600, marginBottom: 6, display: 'block' }}>
                    PASSWORD
                  </label>
                  <input
                    type="password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    style={{
                      width: '100%',
                      padding: '12px 16px',
                      background: 'rgba(0,0,0,0.3)',
                      border: '1px solid rgba(165,180,252,0.2)',
                      borderRadius: 10,
                      color: 'white',
                      fontSize: '1rem',
                      outline: 'none',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>

                {errorMsg && (
                  <div style={{ color: '#f87171', fontSize: '0.8rem', background: 'rgba(248,113,113,0.1)', padding: '10px 12px', borderRadius: 8 }}>
                    ⚠️ {errorMsg}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  className="btn-primary"
                  style={{ width: '100%', padding: '14px', marginTop: 10 }}
                >
                  {loading ? 'Signing in...' : 'Sign In & Sync Data →'}
                </button>

                <p style={{ textAlign: 'center', fontSize: '0.8rem', color: '#8b92b2', margin: '4px 0 0' }}>
                  New user?{' '}
                  <span
                    style={{ color: '#818cf8', cursor: 'pointer', textDecoration: 'underline' }}
                    onClick={() => {
                      setShowSignInModal(false);
                      setScreen('onboarding');
                    }}
                  >
                    Start Onboarding
                  </span>
                </p>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
