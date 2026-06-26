import React, { useState } from 'react';
import { useApp } from '../../../context/AppContext.jsx';

export default function SignUpStep({ onNext }) {
  const { updateProfile } = useApp();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);

  const valid = email.includes('@') && password.length >= 6;

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">🔐</div>
        <h2 className="ob-title" style={{marginTop:12}}>Create Account</h2>
        <p className="ob-subtitle" style={{marginTop:8}}>Secure your sleep data and sync across devices.</p>
      </div>

      <div style={{display:'flex',flexDirection:'column',gap:14}}>
        <div>
          <label style={{fontSize:'0.8rem',color:'#a5b4fc',fontWeight:600,marginBottom:6,display:'block'}}>EMAIL</label>
          <input id="input-email" className="input-field" type="email" placeholder="you@example.com"
            value={email} onChange={e => setEmail(e.target.value)} />
        </div>
        <div>
          <label style={{fontSize:'0.8rem',color:'#a5b4fc',fontWeight:600,marginBottom:6,display:'block'}}>PASSWORD</label>
          <div style={{position:'relative'}}>
            <input id="input-password" className="input-field" type={showPw ? 'text' : 'password'}
              placeholder="Min 6 characters" value={password} onChange={e => setPassword(e.target.value)}
              style={{paddingRight:52}} />
            <button onClick={() => setShowPw(!showPw)} style={{position:'absolute',right:14,top:'50%',transform:'translateY(-50%)',
              background:'none',border:'none',color:'#6b7280',cursor:'pointer',fontSize:'1rem'}}>
              {showPw ? '🙈' : '👁️'}
            </button>
          </div>
        </div>

        {password.length > 0 && (
          <div style={{display:'flex',gap:4}}>
            {[1,2,3,4].map(i => (
              <div key={i} style={{flex:1,height:4,borderRadius:99,
                background: password.length >= i*3 ? (i<=2?'#f97316':i<=3?'#6366f1':'#34d399') : 'rgba(99,102,241,0.15)',
                transition:'background 0.3s'}} />
            ))}
          </div>
        )}
      </div>

      <div className="ob-actions">
        <button id="btn-signup-next" className="btn-primary" disabled={!valid}
          onClick={() => { updateProfile({ email }); onNext(); }}
          style={{opacity: valid ? 1 : 0.5}}>
          Create Account →
        </button>
        <p style={{textAlign:'center',fontSize:'0.78rem',color:'#6b7280'}}>
          Already have an account? <span style={{color:'#818cf8',cursor:'pointer'}} onClick={onNext}>Sign In</span>
        </p>
      </div>
    </div>
  );
}
