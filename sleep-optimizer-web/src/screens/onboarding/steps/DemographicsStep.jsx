import React, { useState } from 'react';
import { useApp } from '../../../context/AppContext.jsx';

const GENDERS = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

export default function DemographicsStep({ onNext }) {
  const { updateProfile } = useApp();
  const [dob, setDob] = useState('');
  const [gender, setGender] = useState('');

  const valid = dob && gender;

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">🧬</div>
        <h2 className="ob-title" style={{marginTop:12}}>About You</h2>
        <p className="ob-subtitle" style={{marginTop:8}}>Helps us tailor sleep recommendations for your biology.</p>
      </div>

      <div style={{display:'flex',flexDirection:'column',gap:20}}>
        <div>
          <label style={{fontSize:'0.8rem',color:'#a5b4fc',fontWeight:600,marginBottom:8,display:'block'}}>DATE OF BIRTH</label>
          <input id="input-dob" className="input-field" type="date" value={dob}
            onChange={e => setDob(e.target.value)}
            style={{colorScheme:'dark'}} />
        </div>

        <div>
          <label style={{fontSize:'0.8rem',color:'#a5b4fc',fontWeight:600,marginBottom:10,display:'block'}}>GENDER</label>
          <div className="chip-group">
            {GENDERS.map(g => (
              <button key={g} className={`chip ${gender === g ? 'selected' : ''}`}
                onClick={() => setGender(g)} id={`chip-gender-${g.toLowerCase().replace(/\s/g,'-')}`}>
                {g}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="ob-actions">
        <button id="btn-demo-next" className="btn-primary" disabled={!valid}
          onClick={() => { updateProfile({ dob, gender }); onNext(); }}
          style={{opacity: valid ? 1 : 0.5}}>
          Continue →
        </button>
      </div>
    </div>
  );
}
