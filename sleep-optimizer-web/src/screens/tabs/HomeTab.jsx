import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useApp } from '../../context/AppContext.jsx';
import './HomeTab.css';

const WIND_DOWN = [
  { id: 'rain', emoji: '🌧️', title: 'Deep Rain', duration: '45 min', color: '#3b82f6' },
  { id: 'meditation', emoji: '🧘', title: 'Meditation', duration: '20 min', color: '#6366f1' },
  { id: 'forest', emoji: '🌲', title: 'Forest Stream', duration: '60 min', color: '#34d399' },
  { id: 'ocean', emoji: '🌊', title: 'Ocean Waves', duration: '30 min', color: '#0ea5e9' },
];

const MOODS = [
  { id: 'good', emoji: '😊', label: 'Good', color: '#34d399' },
  { id: 'okay', emoji: '😐', label: 'Okay', color: '#f97316' },
  { id: 'bad', emoji: '😔', label: 'Bad', color: '#f87171' },
];

export default function HomeTab({ onNavigate }) {
  const { profile, sleepSessions, breathingStreak, breathingProgress, setActiveTab, setNidraOpen } = useApp();
  const [showSleepFlow, setShowSleepFlow] = useState(false);
  const [sleepStep, setSleepStep] = useState(0); // 0=mood, 1=alarm, 2=sound
  const [mood, setMood] = useState(null);
  const [alarmTime, setAlarmTime] = useState('07:00');
  const [vibration, setVibration] = useState(true);
  const [soundAlarm, setSoundAlarm] = useState(true);
  const [selectedSound, setSelectedSound] = useState(null);

  const lastSession = sleepSessions[0];
  const now = new Date();
  const hour = now.getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  const startSleep = () => {
    if (sleepStep < 2) { setSleepStep(s => s + 1); }
    else { onNavigate('sleep-session'); }
  };

  if (showSleepFlow) {
    return (
      <div className="sleep-flow-overlay">
        <div className="sleep-flow-header">
          <button className="ob-back-btn" onClick={() => { setShowSleepFlow(false); setSleepStep(0); }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
          </button>
          <div className="step-dots">
            {[0,1,2].map(i => <div key={i} className={`step-dot ${i===sleepStep?'active':''}`} />)}
          </div>
        </div>

        <AnimatePresence mode="wait">
          <motion.div key={sleepStep} initial={{opacity:0,x:30}} animate={{opacity:1,x:0}} exit={{opacity:0,x:-30}} transition={{duration:0.25}}>

            {sleepStep === 0 && (
              <div className="sleep-flow-step">
                <h3 style={{fontFamily:'Outfit',fontSize:'1.6rem',fontWeight:700}}>How are you feeling?</h3>
                <p style={{color:'#a5b4fc',marginTop:8}}>Your mood affects your sleep quality.</p>
                <div style={{display:'flex',gap:16,marginTop:28,justifyContent:'center'}}>
                  {MOODS.map(m => (
                    <button key={m.id} id={`mood-${m.id}`} onClick={() => setMood(m.id)} style={{
                      display:'flex',flexDirection:'column',alignItems:'center',gap:10,padding:'20px 24px',
                      background: mood===m.id ? `${m.color}18` : 'rgba(255,255,255,0.04)',
                      border:`2px solid ${mood===m.id ? m.color : 'rgba(165,180,252,0.1)'}`,
                      borderRadius:20,cursor:'pointer',transition:'all 0.2s',
                    }}>
                      <span style={{fontSize:'2.5rem'}}>{m.emoji}</span>
                      <span style={{fontSize:'0.85rem',fontWeight:600,color: mood===m.id ? m.color : '#a5b4fc'}}>{m.label}</span>
                    </button>
                  ))}
                </div>
                <button id="btn-mood-next" className="btn-primary" style={{width:'100%',marginTop:32,opacity:mood?1:0.5}} disabled={!mood} onClick={startSleep}>
                  Next →
                </button>
              </div>
            )}

            {sleepStep === 1 && (
              <div className="sleep-flow-step">
                <h3 style={{fontFamily:'Outfit',fontSize:'1.6rem',fontWeight:700}}>Set Your Alarm</h3>
                <p style={{color:'#a5b4fc',marginTop:8}}>When do you want to wake up?</p>
                <div style={{margin:'28px 0',textAlign:'center'}}>
                  <input id="alarm-time" type="time" value={alarmTime} onChange={e=>setAlarmTime(e.target.value)}
                    style={{fontFamily:'Outfit',fontSize:'3rem',fontWeight:800,background:'rgba(99,102,241,0.1)',
                      border:'1px solid rgba(165,180,252,0.2)',borderRadius:16,padding:'16px 24px',
                      color:'#f0f0ff',outline:'none',colorScheme:'dark'}} />
                </div>
                <div style={{display:'flex',flexDirection:'column',gap:14}}>
                  {[{label:'Vibration',val:vibration,set:setVibration,id:'toggle-vib'},
                    {label:'Sound Alarm',val:soundAlarm,set:setSoundAlarm,id:'toggle-sound'}].map(t => (
                    <div key={t.id} style={{display:'flex',justifyContent:'space-between',alignItems:'center',
                      padding:'14px 18px',background:'rgba(255,255,255,0.04)',border:'1px solid rgba(165,180,252,0.1)',borderRadius:14}}>
                      <span style={{color:'#f0f0ff',fontWeight:500}}>{t.label}</span>
                      <label className="toggle" id={t.id}>
                        <input type="checkbox" checked={t.val} onChange={e=>t.set(e.target.checked)} />
                        <span className="toggle-slider" />
                      </label>
                    </div>
                  ))}
                </div>
                <button id="btn-alarm-next" className="btn-primary" style={{width:'100%',marginTop:24}} onClick={startSleep}>Next →</button>
              </div>
            )}

            {sleepStep === 2 && (
              <div className="sleep-flow-step">
                <h3 style={{fontFamily:'Outfit',fontSize:'1.6rem',fontWeight:700}}>Pick a Sleep Sound</h3>
                <p style={{color:'#a5b4fc',marginTop:8}}>Background audio for deeper sleep.</p>
                <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:12,marginTop:24}}>
                  {WIND_DOWN.map(s => (
                    <button key={s.id} id={`sound-select-${s.id}`} onClick={() => setSelectedSound(s.id)} style={{
                      display:'flex',flexDirection:'column',gap:8,padding:'18px',
                      background: selectedSound===s.id ? `${s.color}18` : 'rgba(255,255,255,0.04)',
                      border:`2px solid ${selectedSound===s.id ? s.color : 'rgba(165,180,252,0.1)'}`,
                      borderRadius:18,cursor:'pointer',transition:'all 0.2s',alignItems:'flex-start',
                    }}>
                      <span style={{fontSize:'2rem'}}>{s.emoji}</span>
                      <span style={{fontSize:'0.85rem',fontWeight:600,color: selectedSound===s.id ? s.color : '#f0f0ff'}}>{s.title}</span>
                      <span style={{fontSize:'0.75rem',color:'#a5b4fc'}}>{s.duration}</span>
                    </button>
                  ))}
                </div>
                <button id="btn-start-session" className="btn-primary" style={{width:'100%',marginTop:24}} onClick={startSleep}>
                  🌙 Start Sleep Session
                </button>
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </div>
    );
  }

  return (
    <div className="home-tab">
      {/* Header */}
      <div className="home-header">
        <div>
          <p className="home-greeting">{greeting},</p>
          <h2 className="home-name">{profile.name || 'Sleep Champion'} 🌙</h2>
        </div>
        <button className="home-avatar" id="btn-profile-avatar" onClick={() => setActiveTab('profile')}>
          {(profile.name || 'S')[0].toUpperCase()}
        </button>
      </div>

      {/* Go to Sleep Hero */}
      <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
        <button id="btn-go-to-sleep" className="sleep-hero-btn" onClick={() => setShowSleepFlow(true)}>
          <div className="sleep-hero-glow" />
          <div className="sleep-hero-inner">
            <motion.span className="sleep-hero-moon"
              animate={{ rotate: [0, 10, -10, 0] }}
              transition={{ duration: 6, repeat: Infinity }}
            >🌙</motion.span>
            <div>
              <h3 className="sleep-hero-label">Go to Sleep</h3>
              <p className="sleep-hero-sub">Tap to start your sleep session</p>
            </div>
          </div>
        </button>
      </motion.div>

      {/* Bento Stats */}
      {sleepSessions.length > 0 ? (
        <div className="bento-grid">
          <div className="bento-card bento-score glass-card-sm">
            <p className="bento-label">Sleep Score</p>
            <div className="bento-score-ring">
              <svg viewBox="0 0 80 80" className="score-svg">
                <circle cx="40" cy="40" r="34" fill="none" stroke="rgba(99,102,241,0.15)" strokeWidth="7"/>
                <circle cx="40" cy="40" r="34" fill="none" stroke="#6366f1" strokeWidth="7"
                  strokeDasharray={`${2*Math.PI*34 * lastSession.score/100} ${2*Math.PI*34}`}
                  strokeDashoffset={2*Math.PI*34 * 0.25}
                  strokeLinecap="round" transform="rotate(-90 40 40)"/>
              </svg>
              <span className="score-value">{lastSession.score}</span>
            </div>
            <p className="bento-sub">Last night</p>
          </div>

          <div className="bento-card bento-duration glass-card-sm">
            <p className="bento-label">Duration</p>
            <p className="bento-big">{lastSession.duration}</p>
            <p className="bento-sub" style={{color:'#34d399'}}>✓ Optimal</p>
          </div>

          <div className="bento-card bento-deep glass-card-sm">
            <p className="bento-label">Deep Sleep</p>
            <p className="bento-big">{lastSession.deepSleep}%</p>
            <div className="progress-bar" style={{marginTop:8}}>
              <div className="progress-bar-fill" style={{width:`${lastSession.deepSleep}%`,
                background:'linear-gradient(90deg, #3b82f6, #6366f1)'}} />
            </div>
          </div>

          <div className="bento-card bento-rem glass-card-sm">
            <p className="bento-label">REM Sleep</p>
            <p className="bento-big">{lastSession.rem}%</p>
            <div className="progress-bar" style={{marginTop:8}}>
              <div className="progress-bar-fill" style={{width:`${lastSession.rem}%`,
                background:'linear-gradient(90deg, #6366f1, #a5b4fc)'}} />
            </div>
          </div>
        </div>
      ) : (
        <div style={{margin:'0 20px', padding:'30px 20px', textAlign:'center', background:'rgba(255,255,255,0.04)', borderRadius:20, border:'1px dashed rgba(165,180,252,0.2)'}}>
          <span style={{fontSize:'2.5rem', opacity:0.5}}>🛏️</span>
          <h4 style={{marginTop:12, fontFamily:'Outfit', fontSize:'1.2rem', fontWeight:700, color:'#a5b4fc'}}>No sleep data yet</h4>
          <p style={{fontSize:'0.85rem', color:'#6b7280', marginTop:6}}>Start your first sleep session tonight to unlock your personalized insights.</p>
        </div>
      )}

      {/* AI Sleep Insight */}
      <div className="glow-card" style={{margin:'0 20px'}}>
        <div className="glow-card-inner">
          <div style={{display:'flex',alignItems:'center',gap:10,marginBottom:12}}>
            <img src="/Nidra.png" alt="Nidra" style={{ width: 24, height: 24, objectFit: 'contain' }} />
            <p style={{fontSize:'0.75rem',fontWeight:700,color:'#a5b4fc',letterSpacing:'0.05em',textTransform:'uppercase'}}>Nidra AI Insight</p>
          </div>
          <p style={{color:'#f0f0ff',fontSize:'0.95rem',lineHeight:1.6}}>
            {sleepSessions.length > 0 ? (
              <>
                "Maintain your <strong style={{color:'#818cf8'}}>10:30 PM</strong> bedtime — your last 3 nights show 18% better deep sleep consistency. 
                Reduce screen exposure 30 min before bed for optimal melatonin production."
              </>
            ) : (
              "Welcome! I am Nidra, your AI sleep coach. Record your first sleep session tonight so I can start generating personalized insights for you."
            )}
          </p>
          <button className="btn-ghost" style={{marginTop:12,padding:'8px 0',fontSize:'0.8rem'}}
            onClick={() => setNidraOpen(true)} id="btn-ai-insight-chat">
            Ask Nidra for more → 
          </button>
        </div>
      </div>

      {/* Breathing Exercise */}
      <div style={{margin:'0 20px'}}>
        <div className="glass-card-sm" style={{padding:'18px 20px'}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start',marginBottom:14}}>
            <div>
              <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:6}}>
                <span style={{fontSize:'1.2rem'}}>🫁</span>
                <h4 style={{fontSize:'1rem',fontWeight:700}}>Breathing Exercise</h4>
              </div>
              <p style={{color:'#a5b4fc',fontSize:'0.82rem'}}>4-7-8 technique for calm</p>
            </div>
            <div style={{display:'flex',alignItems:'center',gap:6,background:'rgba(249,115,22,0.1)',
              border:'1px solid rgba(249,115,22,0.25)',borderRadius:20,padding:'4px 10px'}}>
              <span style={{fontSize:'0.85rem'}}>🔥</span>
              <span style={{fontSize:'0.8rem',fontWeight:700,color:'#f97316'}}>{breathingStreak} Day Streak</span>
            </div>
          </div>
          <div style={{marginBottom:14}}>
            <div style={{display:'flex',justifyContent:'space-between',marginBottom:6}}>
              <span style={{fontSize:'0.8rem',color:'#a5b4fc'}}>Daily Progress</span>
              <span style={{fontSize:'0.8rem',color:'#f0f0ff',fontWeight:600}}>{breathingProgress}/5 sessions</span>
            </div>
            <div className="progress-bar">
              <div className="progress-bar-fill" style={{width:`${breathingProgress/5*100}%`,
                background:'linear-gradient(90deg, #34d399, #6366f1)'}} />
            </div>
          </div>
          <button id="btn-breathing-start" className="btn-primary" style={{width:'100%'}} onClick={() => onNavigate('breathing')}>
            Start Session ✨
          </button>
        </div>
      </div>

      {/* Wind Down */}
      <div style={{margin:'0 20px'}}>
        <div className="section-header">
          <h3 className="section-title">Wind Down</h3>
          <span className="section-link" onClick={() => setActiveTab('sounds')} id="link-sounds">See all</span>
        </div>
        <div className="scroll-row">
          {WIND_DOWN.map(s => (
            <div key={s.id} className="wind-down-card glass-card-sm" style={{borderColor:`${s.color}30`}}>
              <span style={{fontSize:'2rem'}}>{s.emoji}</span>
              <p style={{fontWeight:600,fontSize:'0.85rem',color:'#f0f0ff',marginTop:8}}>{s.title}</p>
              <p style={{fontSize:'0.75rem',color:'#a5b4fc',marginTop:4}}>{s.duration}</p>
              <button className="wind-play-btn" id={`btn-wind-${s.id}`}
                style={{background:`${s.color}25`,border:`1px solid ${s.color}50`,color:s.color}}>
                ▶ Play
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
