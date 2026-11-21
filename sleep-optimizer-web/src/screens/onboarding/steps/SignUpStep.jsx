import React, { useState } from 'react';
import { useApp } from '../../../context/AppContext.jsx';

export default function SignUpStep({ onNext }) {
  const { profile, updateProfile, loginUser } = useApp();
  const [isSignInMode, setIsSignInMode] = useState(false);
  const [email, setEmail] = useState(profile.email || '');
  const [password, setPassword] = useState(profile.password || '');
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  const valid = email.includes('@') && password.length >= 6;

  const handleNext = async () => {
    setErrorMsg('');
    if (isSignInMode) {
      setLoading(true);
      try {
        await loginUser(email.trim().toLowerCase(), password);
      } catch (err) {
        console.error('Sign in error:', err);
        setErrorMsg(err.message || 'Failed to sign in. Please check your credentials.');
      } finally {
        setLoading(false);
      }
    } else {
      updateProfile({ email: email.trim().toLowerCase(), password }, false);
      onNext();
    }
  };

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">{isSignInMode ? '🔑' : '🔐'}</div>
        <h2 className="ob-title" style={{ marginTop: 12 }}>
          {isSignInMode ? 'Sign In' : 'Create Account'}
        </h2>
        <p className="ob-subtitle" style={{ marginTop: 8 }}>
          {isSignInMode
            ? 'Access your saved sleep records and sync across devices.'
            : 'Secure your sleep data in the cloud and sync across devices.'}
        </p>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div>
          <label style={{ fontSize: '0.8rem', color: '#a5b4fc', fontWeight: 600, marginBottom: 6, display: 'block' }}>
            EMAIL
          </label>
          <input
            id="input-email"
            className="input-field"
            type="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div>
          <label style={{ fontSize: '0.8rem', color: '#a5b4fc', fontWeight: 600, marginBottom: 6, display: 'block' }}>
            PASSWORD
          </label>
          <div style={{ position: 'relative' }}>
            <input
              id="input-password"
              className="input-field"
              type={showPw ? 'text' : 'password'}
              placeholder="Min 6 characters"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={{ paddingRight: 52 }}
            />
            <button
              type="button"
              onClick={() => setShowPw(!showPw)}
              style={{
                position: 'absolute',
                right: 14,
                top: '50%',
                transform: 'translateY(-50%)',
                background: 'none',
                border: 'none',
                color: '#6b7280',
                cursor: 'pointer',
                fontSize: '1rem',
              }}
            >
              {showPw ? '🙈' : '👁️'}
            </button>
          </div>
        </div>

        {errorMsg && (
          <div style={{ color: '#f87171', fontSize: '0.82rem', background: 'rgba(248,113,113,0.1)', padding: '10px 14px', borderRadius: 8, border: '1px solid rgba(248,113,113,0.3)' }}>
            ⚠️ {errorMsg}
          </div>
        )}

        {!isSignInMode && password.length > 0 && (
          <div style={{ display: 'flex', gap: 4 }}>
            {[1, 2, 3, 4].map((i) => (
              <div
                key={i}
                style={{
                  flex: 1,
                  height: 4,
                  borderRadius: 99,
                  background:
                    password.length >= i * 3
                      ? i <= 2
                        ? '#f97316'
                        : i <= 3
                        ? '#6366f1'
                        : '#34d399'
                      : 'rgba(99,102,241,0.15)',
                  transition: 'background 0.3s',
                }}
              />
            ))}
          </div>
        )}
      </div>

      <div className="ob-actions">
        <button
          id="btn-signup-next"
          className="btn-primary"
          disabled={!valid || loading}
          onClick={handleNext}
          style={{ opacity: valid && !loading ? 1 : 0.5 }}
        >
          {loading
            ? 'Please wait...'
            : isSignInMode
            ? 'Sign In & Load Data →'
            : 'Continue With Account →'}
        </button>
        <p style={{ textAlign: 'center', fontSize: '0.78rem', color: '#6b7280' }}>
          {isSignInMode ? "Don't have an account? " : 'Already have an account? '}
          <span
            style={{ color: '#818cf8', cursor: 'pointer', textDecoration: 'underline' }}
            onClick={() => {
              setIsSignInMode(!isSignInMode);
              setErrorMsg('');
            }}
          >
            {isSignInMode ? 'Create New Account' : 'Sign In'}
          </span>
        </p>
      </div>
    </div>
  );
}
