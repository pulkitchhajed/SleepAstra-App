import React, { useState } from 'react';
import { useApp } from '../../../context/AppContext.jsx';

const options = {
  caffeine: { label: 'Daily Caffeine', icon: '☕', opts: ['None', 'Light (1 cup)', 'Moderate (2-3)', 'Heavy (4+)'] },
  exercise: { label: 'Exercise Frequency', icon: '🏃', opts: ['Rarely', 'Sometimes', '3-4x/week', 'Daily'] },
  screenTime: { label: 'Screen Time Before Bed', icon: '📱', opts: ['None', '<30 min', '1-2 hours', '2+ hours'] },
};

export default function LifestyleStep({ onNext }) {
  const { updateProfile } = useApp();
  const [lifestyle, setLifestyle] = useState({ caffeine: '', exercise: '', screenTime: '' });

  const valid = Object.values(lifestyle).every(Boolean);

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">🌿</div>
        <h2 className="ob-title" style={{marginTop:12}}>Your Lifestyle</h2>
        <p className="ob-subtitle" style={{marginTop:8}}>These habits directly impact your sleep quality.</p>
      </div>

      <div style={{display:'flex',flexDirection:'column',gap:22}}>
        {Object.entries(options).map(([key, { label, icon, opts }]) => (
          <div key={key}>
            <p style={{fontSize:'0.85rem',color:'#a5b4fc',fontWeight:600,marginBottom:10}}>
              {icon} {label}
            </p>
            <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
              {opts.map(opt => (
                <button key={opt} id={`lifestyle-${key}-${opt.replace(/\s/g,'-').toLowerCase()}`}
                  className={`chip ${lifestyle[key] === opt ? 'selected' : ''}`}
                  onClick={() => setLifestyle(prev => ({ ...prev, [key]: opt }))}>
                  {opt}
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="ob-actions">
        <button id="btn-lifestyle-next" className="btn-primary" disabled={!valid}
          onClick={() => { updateProfile({ lifestyle }); onNext(); }}
          style={{opacity: valid ? 1 : 0.5}}>
          Continue →
        </button>
      </div>
    </div>
  );
}
