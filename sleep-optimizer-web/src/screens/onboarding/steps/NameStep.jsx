import React, { useState } from 'react';
import { useApp } from '../../../context/AppContext.jsx';

export default function NameStep({ onNext }) {
  const { profile, updateProfile } = useApp();
  const [name, setName] = useState(profile.name || '');

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">👋</div>
        <h2 className="ob-title" style={{marginTop:12}}>What's your name?</h2>
        <p className="ob-subtitle" style={{marginTop:8}}>We'll use this to personalize your experience.</p>
      </div>

      <input
        id="input-name"
        className="input-field"
        placeholder="Enter your first name"
        value={name}
        onChange={e => setName(e.target.value)}
        autoFocus
        style={{fontSize:'1.1rem', padding:'18px'}}
      />

      {name.trim() && (
        <div style={{background:'rgba(99,102,241,0.1)',border:'1px solid rgba(165,180,252,0.15)',borderRadius:16,padding:'16px 20px'}}>
          <p style={{color:'#a5b4fc',fontSize:'0.9rem'}}>Great to meet you,</p>
          <p style={{fontFamily:'Outfit',fontSize:'1.4rem',fontWeight:700,color:'#f0f0ff'}}>{name} 🌙</p>
        </div>
      )}

      <div className="ob-actions">
        <button
          id="btn-name-next"
          className="btn-primary"
          disabled={!name.trim()}
          onClick={() => { updateProfile({ name: name.trim() }); onNext(); }}
          style={{opacity: name.trim() ? 1 : 0.5}}
        >
          Continue →
        </button>
      </div>
    </div>
  );
}
