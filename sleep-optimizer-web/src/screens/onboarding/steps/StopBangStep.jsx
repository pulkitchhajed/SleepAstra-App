import React, { useState } from 'react';
import { useApp } from '../../../context/AppContext.jsx';

const QUESTIONS = [
  { key: 's', label: 'Do you Snore loudly?', icon: '😴' },
  { key: 't', label: 'Do you often feel Tired, fatigued, or sleepy during the daytime?', icon: '😩' },
  { key: 'o', label: 'Has anyone Observed you stop breathing during sleep?', icon: '👀' },
  { key: 'p', label: 'Do you have or are you being treated for high blood Pressure?', icon: '💉' },
  { key: 'b', label: 'Is your BMI more than 35?', icon: '⚖️' },
  { key: 'a', label: 'Are you older than 50 years of Age?', icon: '🎂' },
  { key: 'n', label: 'Is your Neck circumference greater than 40 cm (16 inches)?', icon: '🧣' },
  { key: 'g', label: 'Are you male (Gender)?', icon: '♂️' },
];

export default function StopBangStep({ onNext }) {
  const { profile, updateProfile } = useApp();
  const [answers, setAnswers] = useState(profile.stopBang || {});

  const toggle = (key) => setAnswers(prev => ({ ...prev, [key]: !prev[key] }));
  const score = Object.values(answers).filter(Boolean).length;
  const allAnswered = QUESTIONS.every(q => q.key in answers);

  const risk = score <= 2 ? { label: 'Low Risk', color: '#34d399' } :
               score <= 4 ? { label: 'Moderate Risk', color: '#f97316' } :
               { label: 'High Risk', color: '#f87171' };

  return (
    <div className="ob-step-content">
      <div>
        <div className="ob-icon">🩺</div>
        <h2 className="ob-title" style={{marginTop:12}}>STOP-BANG</h2>
        <p className="ob-subtitle" style={{marginTop:8}}>Clinical screening for obstructive sleep apnea. Answer Yes or No.</p>
      </div>

      <div style={{display:'flex',flexDirection:'column',gap:10}}>
        {QUESTIONS.map(q => (
          <div key={q.key} style={{
            display:'flex',alignItems:'center',gap:14,padding:'14px 16px',
            background: answers[q.key] ? 'rgba(99,102,241,0.12)' : 'rgba(255,255,255,0.04)',
            border: answers[q.key] ? '1px solid #6366f1' : '1px solid rgba(165,180,252,0.1)',
            borderRadius:14,cursor:'pointer',transition:'all 0.2s',
          }} onClick={() => toggle(q.key)} id={`stopbang-${q.key}`}>
            <span style={{fontSize:'1.4rem',flexShrink:0}}>{q.icon}</span>
            <p style={{flex:1,fontSize:'0.85rem',color:answers[q.key]?'#c7d2fe':'#a5b4fc',lineHeight:1.4}}>{q.label}</p>
            <div style={{
              width:24,height:24,borderRadius:12,border:'2px solid',flexShrink:0,
              borderColor: answers[q.key] ? '#6366f1' : 'rgba(165,180,252,0.3)',
              background: answers[q.key] ? '#6366f1' : 'transparent',
              display:'flex',alignItems:'center',justifyContent:'center',
              transition:'all 0.2s',
            }}>
              {answers[q.key] && <span style={{color:'white',fontSize:'0.75rem',fontWeight:700}}>✓</span>}
            </div>
          </div>
        ))}
      </div>

      {allAnswered && (
        <div style={{background:`rgba(${score>=5?'248,113,113':score>=3?'249,115,22':'52,211,153'},.08)`,
          border:`1px solid ${risk.color}40`,borderRadius:16,padding:'16px 20px',
          display:'flex',alignItems:'center',justifyContent:'space-between'}}>
          <div>
            <p style={{fontSize:'0.78rem',color:'#a5b4fc'}}>Your Sleep Apnea Risk</p>
            <p style={{fontFamily:'Outfit',fontSize:'1.3rem',fontWeight:700,color:risk.color}}>{risk.label}</p>
          </div>
          <div style={{fontFamily:'Outfit',fontSize:'2rem',fontWeight:900,color:risk.color}}>{score}/8</div>
        </div>
      )}

      <div className="ob-actions">
        <button id="btn-stopbang-next" className="btn-primary" disabled={!allAnswered}
          onClick={() => { updateProfile({ stopBang: answers }); onNext(); }}
          style={{opacity: allAnswered ? 1 : 0.5}}>
          Continue →
        </button>
      </div>
    </div>
  );
}
