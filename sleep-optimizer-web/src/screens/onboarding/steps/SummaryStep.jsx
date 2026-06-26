import React from 'react';
import { useApp } from '../../../context/AppContext.jsx';

export default function SummaryStep({ onNext }) {
  const { profile } = useApp();
  const sbScore = Object.values(profile.stopBang || {}).filter(Boolean).length;

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">📋</div>
        <h2 className="ob-title" style={{marginTop:12}}>Your Profile</h2>
        <p className="ob-subtitle" style={{marginTop:8}}>Here's a summary before we get started.</p>
      </div>

      <div style={{display:'flex',flexDirection:'column',gap:12}}>
        {[
          { label: 'Name', value: profile.name || '—' },
          { label: 'Email', value: profile.email || '—' },
          { label: 'Gender', value: profile.gender || '—' },
          { label: 'Goals', value: profile.goals?.length > 0 ? `${profile.goals.length} selected` : '—' },
          { label: 'STOP-BANG Score', value: `${sbScore}/8 — ${sbScore<=2?'Low':sbScore<=4?'Moderate':'High'} Risk` },
          { label: 'Caffeine', value: profile.lifestyle?.caffeine || '—' },
          { label: 'Exercise', value: profile.lifestyle?.exercise || '—' },
          { label: 'Screen Time', value: profile.lifestyle?.screenTime || '—' },
        ].map(item => (
          <div key={item.label} style={{
            display:'flex',justifyContent:'space-between',alignItems:'center',
            padding:'14px 16px',background:'rgba(255,255,255,0.04)',
            border:'1px solid rgba(165,180,252,0.1)',borderRadius:12,
          }}>
            <span style={{fontSize:'0.85rem',color:'#a5b4fc',fontWeight:500}}>{item.label}</span>
            <span style={{fontSize:'0.9rem',color:'#f0f0ff',fontWeight:600}}>{item.value}</span>
          </div>
        ))}
      </div>

      <div className="ob-actions">
        <button id="btn-summary-confirm" className="btn-primary" onClick={onNext}>
          Everything looks good ✓
        </button>
      </div>
    </div>
  );
}
