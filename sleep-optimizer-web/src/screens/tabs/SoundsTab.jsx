import React, { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import './SoundsTab.css';

const NOISE_SOUNDS = [
  { id: 'brown', emoji: '🟤', label: 'Brown Noise' },
  { id: 'pink',  emoji: '🌸', label: 'Pink Noise' },
  { id: 'white', emoji: '⬜', label: 'White Noise' },
  { id: 'fan',   emoji: '💨', label: 'Fan' },
  { id: 'rain',  emoji: '🌧️', label: 'Rain' },
  { id: 'thunder', emoji: '⛈️', label: 'Thunder' },
  { id: 'fire',  emoji: '🔥', label: 'Fireplace' },
  { id: 'ocean', emoji: '🌊', label: 'Ocean' },
];

const MEDITATIONS = [
  { id: 'm1', title: 'Body Scan Sleep', instructor: 'Dr. Sarah Lin', duration: '18 min', emoji: '🌙' },
  { id: 'm2', title: 'Anxiety Release', instructor: 'Coach Marcus', duration: '12 min', emoji: '🌬️' },
  { id: 'm3', title: 'Deep Relaxation', instructor: 'Dr. Priya Nair', duration: '25 min', emoji: '🫧' },
  { id: 'm4', title: 'Gratitude Drift', instructor: 'Maya Chen', duration: '10 min', emoji: '✨' },
];

const SOUNDSCAPES = [
  { id: 'midnight-rain', title: 'Midnight Rain', desc: 'Deep forest rainfall', emoji: '🌧️', color: '#3b82f6' },
  { id: 'space', title: 'Deep Space', desc: 'Cosmic ambient drone', emoji: '🌌', color: '#6366f1' },
  { id: 'cabin', title: 'Winter Cabin', desc: 'Fireplace & wind', emoji: '🏠', color: '#f97316' },
  { id: 'beach', title: 'Tropical Beach', desc: 'Waves & birds', emoji: '🏖️', color: '#0ea5e9' },
];

const TIMERS = [15, 30, 45, 60];

export default function SoundsTab() {
  const [volumes, setVolumes] = useState({});
  const [activeNoise, setActiveNoise] = useState({});
  const [activeMeditation, setActiveMeditation] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(34);
  const [timer, setTimer] = useState(null);

  const toggleNoise = (id) => {
    setActiveNoise(prev => ({ ...prev, [id]: !prev[id] }));
    setVolumes(prev => ({ ...prev, [id]: prev[id] ?? 60 }));
  };

  return (
    <div className="sounds-tab">
      <div style={{ padding: '24px 20px 0' }}>
        <h2 style={{ fontFamily: 'Outfit', fontSize: '1.8rem', fontWeight: 800 }}>Wellness Hub</h2>
        <p style={{ color: '#a5b4fc', marginTop: 4 }}>Curated sounds for restful sleep</p>
      </div>

      {/* Sleep Timer */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">⏱️ Sleep Timer</h3>
          {timer && <span className="badge badge-success">{timer} min active</span>}
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          {TIMERS.map(t => (
            <button key={t} id={`timer-${t}`} onClick={() => setTimer(timer === t ? null : t)}
              style={{
                flex: 1, padding: '12px 0', borderRadius: 14, cursor: 'pointer', fontWeight: 700,
                fontSize: '0.9rem', transition: 'all 0.2s',
                background: timer === t ? 'rgba(52,211,153,0.15)' : 'rgba(255,255,255,0.04)',
                border: `1px solid ${timer === t ? '#34d399' : 'rgba(165,180,252,0.1)'}`,
                color: timer === t ? '#34d399' : '#a5b4fc',
              }}>
              {t}m
            </button>
          ))}
        </div>
        {timer && (
          <p style={{ fontSize: '0.78rem', color: '#6b7280', marginTop: 8, textAlign: 'center' }}>
            Audio will fade out gradually after {timer} minutes
          </p>
        )}
      </div>

      {/* Noise Mixer */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">🎛️ Noise Mixer</h3>
        </div>
        <div className="glass-card-sm" style={{ padding: '16px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            {NOISE_SOUNDS.map(s => (
              <div key={s.id} className={`noise-card ${activeNoise[s.id] ? 'active' : ''}`} id={`noise-${s.id}`}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: '1.3rem' }}>{s.emoji}</span>
                    <span style={{ fontSize: '0.8rem', fontWeight: 600, color: activeNoise[s.id] ? '#c7d2fe' : '#a5b4fc' }}>{s.label}</span>
                  </div>
                  <button onClick={() => toggleNoise(s.id)} style={{
                    width: 28, height: 28, borderRadius: '50%', border: 'none', cursor: 'pointer',
                    background: activeNoise[s.id] ? '#6366f1' : 'rgba(99,102,241,0.15)',
                    color: 'white', fontSize: '0.7rem', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    transition: 'all 0.2s',
                  }}>
                    {activeNoise[s.id] ? '⏸' : '▶'}
                  </button>
                </div>
                {activeNoise[s.id] && (
                  <input type="range" min={0} max={100}
                    value={volumes[s.id] ?? 60}
                    onChange={e => setVolumes(prev => ({ ...prev, [s.id]: Number(e.target.value) }))}
                  />
                )}
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Meditation Player */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">🧘 Guided Meditation</h3>
        </div>

        {activeMeditation && (
          <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} className="med-player glass-card" style={{ padding: '20px', marginBottom: 14 }}>
            <div style={{ textAlign: 'center', marginBottom: 16 }}>
              <div style={{ fontSize: '3.5rem', marginBottom: 8, filter: 'drop-shadow(0 0 20px rgba(99,102,241,0.6))' }}>
                {activeMeditation.emoji}
              </div>
              <h4 style={{ fontFamily: 'Outfit', fontSize: '1.1rem', fontWeight: 700 }}>{activeMeditation.title}</h4>
              <p style={{ color: '#a5b4fc', fontSize: '0.82rem' }}>{activeMeditation.instructor}</p>
            </div>
            <div style={{ marginBottom: 16 }}>
              <div className="progress-bar" style={{ height: 4 }}>
                <div className="progress-bar-fill" style={{ width: `${progress}%` }} />
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
                <span style={{ fontSize: '0.72rem', color: '#6b7280' }}>4:05</span>
                <span style={{ fontSize: '0.72rem', color: '#6b7280' }}>{activeMeditation.duration}</span>
              </div>
            </div>
            <div style={{ display: 'flex', justifyContent: 'center', gap: 20 }}>
              {['⏮', isPlaying ? '⏸' : '▶', '⏭'].map((ctrl, i) => (
                <button key={i} onClick={() => i === 1 && setIsPlaying(!isPlaying)} style={{
                  width: i === 1 ? 52 : 40, height: i === 1 ? 52 : 40, borderRadius: '50%',
                  background: i === 1 ? 'linear-gradient(135deg, #6366f1, #818cf8)' : 'rgba(99,102,241,0.15)',
                  border: i === 1 ? 'none' : '1px solid rgba(165,180,252,0.15)',
                  color: 'white', fontSize: i === 1 ? '1.2rem' : '1rem', cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: i === 1 ? '0 0 20px rgba(99,102,241,0.5)' : 'none', transition: 'all 0.2s',
                }}>
                  {ctrl}
                </button>
              ))}
            </div>
          </motion.div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {MEDITATIONS.map(m => (
            <div key={m.id} id={`med-${m.id}`}
              className={`glass-card-sm med-item ${activeMeditation?.id === m.id ? 'active' : ''}`}
              style={{ padding: '14px 16px', cursor: 'pointer' }}
              onClick={() => { setActiveMeditation(m); setIsPlaying(true); }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <div style={{ fontSize: '2rem', width: 48, height: 48, borderRadius: 14, background: 'rgba(99,102,241,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {m.emoji}
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ fontWeight: 600, color: '#f0f0ff', fontSize: '0.9rem' }}>{m.title}</p>
                  <p style={{ color: '#a5b4fc', fontSize: '0.78rem', marginTop: 2 }}>{m.instructor}</p>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <span style={{ fontSize: '0.78rem', color: '#6b7280' }}>{m.duration}</span>
                  {activeMeditation?.id === m.id && (
                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#34d399', margin: '4px auto 0', boxShadow: '0 0 8px #34d399' }} />
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Soundscapes */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">🌍 Soundscapes</h3>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          {SOUNDSCAPES.map(s => (
            <div key={s.id} id={`scape-${s.id}`} className="soundscape-card" style={{ borderColor: `${s.color}30`, background: `${s.color}0a` }}>
              <span style={{ fontSize: '2.5rem', filter: `drop-shadow(0 0 12px ${s.color}60)` }}>{s.emoji}</span>
              <h4 style={{ fontFamily: 'Outfit', fontWeight: 700, fontSize: '0.95rem', marginTop: 10, color: '#f0f0ff' }}>{s.title}</h4>
              <p style={{ fontSize: '0.75rem', color: '#a5b4fc', marginTop: 4 }}>{s.desc}</p>
              <button style={{
                marginTop: 14, padding: '8px 20px', borderRadius: 99, border: `1px solid ${s.color}50`,
                background: `${s.color}18`, color: s.color, fontSize: '0.8rem', fontWeight: 600, cursor: 'pointer', width: '100%',
              }}>
                ▶ Play
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
