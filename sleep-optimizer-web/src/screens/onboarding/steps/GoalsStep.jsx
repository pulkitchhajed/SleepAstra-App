import React, { useState } from 'react';
import { useApp } from '../../../context/AppContext.jsx';

const GOALS = [
  { id: 'faster', emoji: '⚡', label: 'Fall asleep faster' },
  { id: 'snoring', emoji: '🤫', label: 'Stop snoring' },
  { id: 'refreshed', emoji: '☀️', label: 'Wake up refreshed' },
  { id: 'deeper', emoji: '🌊', label: 'Sleep deeper' },
  { id: 'consistent', emoji: '📅', label: 'Consistent schedule' },
  { id: 'anxiety', emoji: '🧘', label: 'Reduce sleep anxiety' },
  { id: 'apnea', emoji: '🩺', label: 'Screen for apnea' },
  { id: 'energy', emoji: '🔋', label: 'More daytime energy' },
];

export default function GoalsStep({ onNext }) {
  const { updateProfile } = useApp();
  const [selected, setSelected] = useState([]);

  const toggle = (id) => setSelected(prev =>
    prev.includes(id) ? prev.filter(g => g !== id) : [...prev, id]
  );

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">🎯</div>
        <h2 className="ob-title" style={{marginTop:12}}>Your Sleep Goals</h2>
        <p className="ob-subtitle" style={{marginTop:8}}>Select everything that matters to you (pick multiple).</p>
      </div>

      <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}>
        {GOALS.map(g => (
          <button
            key={g.id}
            id={`goal-${g.id}`}
            onClick={() => toggle(g.id)}
            style={{
              display:'flex',flexDirection:'column',alignItems:'flex-start',gap:6,
              padding:'14px 16px',borderRadius:16,cursor:'pointer',
              background: selected.includes(g.id) ? 'rgba(99,102,241,0.15)' : 'rgba(255,255,255,0.04)',
              border: selected.includes(g.id) ? '1px solid #6366f1' : '1px solid rgba(165,180,252,0.12)',
              transition:'all 0.2s',textAlign:'left',
              boxShadow: selected.includes(g.id) ? '0 0 12px rgba(99,102,241,0.25)' : 'none',
            }}
          >
            <span style={{fontSize:'1.5rem'}}>{g.emoji}</span>
            <span style={{fontSize:'0.82rem',fontWeight:600,
              color: selected.includes(g.id) ? '#c7d2fe' : '#a5b4fc',lineHeight:1.3}}>
              {g.label}
            </span>
          </button>
        ))}
      </div>

      <div className="ob-actions">
        <button id="btn-goals-next" className="btn-primary" disabled={selected.length === 0}
          onClick={() => { updateProfile({ goals: selected }); onNext(); }}
          style={{opacity: selected.length > 0 ? 1 : 0.5}}>
          {selected.length > 0 ? `Continue with ${selected.length} goal${selected.length > 1 ? 's' : ''} →` : 'Select at least one'}
        </button>
      </div>
    </div>
  );
}
