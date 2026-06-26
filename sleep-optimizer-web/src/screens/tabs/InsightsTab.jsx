import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { LineChart, Line, AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts';
import { useApp } from '../../context/AppContext.jsx';
import './InsightsTab.css';

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const SLEEP_STAGE_DATA = [
  { time: '11PM', stage: 1, label: 'Light' },
  { time: '12AM', stage: 3, label: 'Deep' },
  { time: '1AM',  stage: 3, label: 'Deep' },
  { time: '2AM',  stage: 2, label: 'REM' },
  { time: '3AM',  stage: 1, label: 'Light' },
  { time: '4AM',  stage: 3, label: 'Deep' },
  { time: '5AM',  stage: 2, label: 'REM' },
  { time: '6AM',  stage: 1, label: 'Light' },
  { time: '7AM',  stage: 0, label: 'Awake' },
];

const SNORE_DATA = [
  { time: '11PM', level: 12 }, { time: '12AM', level: 8 },
  { time: '1AM',  level: 45 }, { time: '2AM',  level: 20 },
  { time: '3AM',  level: 72 }, { time: '4AM',  level: 35 },
  { time: '5AM',  level: 18 }, { time: '6AM',  level: 9 },
];

const SLEEP_DEBT_DATA = [
  { day: 'Mon', actual: 7.3, target: 8 },
  { day: 'Tue', actual: 6.8, target: 8 },
  { day: 'Wed', actual: 8.1, target: 8 },
  { day: 'Thu', actual: 6.2, target: 8 },
  { day: 'Fri', actual: 7.8, target: 8 },
  { day: 'Sat', actual: 8.5, target: 8 },
  { day: 'Sun', actual: 7.3, target: 8 },
];

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{ background: 'rgba(20,17,58,0.95)', border: '1px solid rgba(165,180,252,0.2)', borderRadius: 12, padding: '10px 14px' }}>
      <p style={{ color: '#a5b4fc', fontSize: '0.75rem' }}>{label}</p>
      {payload.map((p, i) => (
        <p key={i} style={{ color: p.color, fontWeight: 600, fontSize: '0.9rem' }}>{p.name}: {p.value}</p>
      ))}
    </div>
  );
};

const STAGE_COLORS = { 0: '#f87171', 1: '#a5b4fc', 2: '#6366f1', 3: '#3b82f6' };
const STAGE_NAMES = { 0: 'Awake', 1: 'Light', 2: 'REM', 3: 'Deep' };

export default function InsightsTab() {
  const { sleepSessions } = useApp();
  const [selectedDate, setSelectedDate] = useState(0);

  if (!sleepSessions || sleepSessions.length === 0) {
    return (
      <div className="insights-tab">
        <div style={{ padding: '24px 20px 0' }}>
          <h2 style={{ fontFamily: 'Outfit', fontSize: '1.8rem', fontWeight: 800 }}>Sleep Insights</h2>
          <p style={{ color: '#a5b4fc', marginTop: 4 }}>Your personal sleep analytics</p>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, padding: 40, textAlign: 'center', marginTop: 40 }}>
          <div style={{ fontSize: '4rem', filter: 'drop-shadow(0 0 20px rgba(99,102,241,0.5))', marginBottom: 20 }}>📊</div>
          <h3 style={{ fontFamily: 'Outfit', fontSize: '1.5rem', fontWeight: 700, color: '#f0f0ff' }}>No data to analyze</h3>
          <p style={{ color: '#a5b4fc', marginTop: 10, lineHeight: 1.6 }}>Record your first sleep session on the Home tab to start tracking your sleep stages, snore detection, and sleep debt.</p>
        </div>
      </div>
    );
  }

  const session = sleepSessions[selectedDate];

  const dates = sleepSessions.map((s, i) => {
    const d = new Date(s.date);
    return { day: DAYS[d.getDay() === 0 ? 6 : d.getDay() - 1], date: d.getDate(), index: i, score: s.score };
  });

  const scoreColor = session.score >= 80 ? '#34d399' : session.score >= 60 ? '#f97316' : '#f87171';

  return (
    <div className="insights-tab">
      {/* Header */}
      <div style={{ padding: '24px 20px 0' }}>
        <h2 style={{ fontFamily: 'Outfit', fontSize: '1.8rem', fontWeight: 800 }}>Sleep Insights</h2>
        <p style={{ color: '#a5b4fc', marginTop: 4 }}>Your personal sleep analytics</p>
      </div>

      {/* Calendar Strip */}
      <div style={{ padding: '0 20px' }}>
        <div className="calendar-strip">
          {dates.map((d) => (
            <button
              key={d.index}
              id={`date-${d.date}`}
              className={`cal-day ${selectedDate === d.index ? 'active' : ''}`}
              onClick={() => setSelectedDate(d.index)}
            >
              <span className="cal-day-name">{d.day}</span>
              <span className="cal-day-num">{d.date}</span>
              <div className="cal-dot" style={{
                background: d.score >= 80 ? '#34d399' : d.score >= 60 ? '#f97316' : '#f87171',
                boxShadow: selectedDate === d.index ? `0 0 8px ${d.score >= 80 ? '#34d399' : d.score >= 60 ? '#f97316' : '#f87171'}` : 'none',
              }} />
            </button>
          ))}
        </div>
      </div>

      {/* Score Card */}
      <AnimatePresence mode="wait">
        <motion.div key={selectedDate}
          initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}
          style={{ padding: '0 20px' }}
        >
          <div className="glass-card" style={{ padding: '20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <p style={{ fontSize: '0.75rem', color: '#a5b4fc', fontWeight: 700, letterSpacing: '0.05em', textTransform: 'uppercase' }}>Sleep Score</p>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
                  <span style={{ fontFamily: 'Outfit', fontSize: '3rem', fontWeight: 900, color: scoreColor }}>{session.score}</span>
                  <span style={{ color: '#6b7280', fontSize: '1rem' }}>/100</span>
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <p style={{ color: '#a5b4fc', fontSize: '0.8rem' }}>Duration</p>
                <p style={{ fontFamily: 'Outfit', fontSize: '1.4rem', fontWeight: 700, color: '#f0f0ff' }}>{session.duration}</p>
                <span className="badge badge-success" style={{ marginTop: 4 }}>✓ Optimal</span>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
              {[
                { label: 'Deep Sleep', value: `${session.deepSleep}%`, color: '#3b82f6' },
                { label: 'REM Sleep', value: `${session.rem}%`, color: '#6366f1' },
                { label: 'Restlessness', value: session.restlessness, color: session.restlessness === 'Low' ? '#34d399' : session.restlessness === 'Medium' ? '#f97316' : '#f87171' },
              ].map(item => (
                <div key={item.label} style={{ background: 'rgba(255,255,255,0.04)', borderRadius: 12, padding: '12px', textAlign: 'center' }}>
                  <p style={{ fontSize: '0.7rem', color: '#6b7280', marginBottom: 6 }}>{item.label}</p>
                  <p style={{ fontFamily: 'Outfit', fontSize: '1.1rem', fontWeight: 700, color: item.color }}>{item.value}</p>
                </div>
              ))}
            </div>

            <div style={{ marginTop: 16, padding: '12px 14px', background: 'rgba(99,102,241,0.08)', borderRadius: 12, borderLeft: '3px solid #6366f1' }}>
              <p style={{ fontSize: '0.78rem', color: '#a5b4fc', fontWeight: 700, marginBottom: 4 }}>🤖 Nidra Insight</p>
              <p style={{ fontSize: '0.85rem', color: '#f0f0ff', lineHeight: 1.5 }}>
                {session.score >= 80
                  ? "Excellent recovery! Your deep sleep cycle was well-structured. Keep your consistent bedtime."
                  : session.score >= 60
                  ? "Moderate night — your REM phases were fragmented. Try limiting caffeine after 2 PM."
                  : "Poor sleep detected. Consider a relaxing wind-down routine and reduce screen time before bed."}
              </p>
            </div>
          </div>
        </motion.div>
      </AnimatePresence>

      {/* Sleep Stages Chart */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">Sleep Stages</h3>
        </div>
        <div className="glass-card-sm" style={{ padding: '16px' }}>
          <div style={{ display: 'flex', gap: 12, marginBottom: 12, flexWrap: 'wrap' }}>
            {Object.entries(STAGE_NAMES).map(([k, v]) => (
              <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: STAGE_COLORS[k] }} />
                <span style={{ fontSize: '0.72rem', color: '#a5b4fc' }}>{v}</span>
              </div>
            ))}
          </div>
          <ResponsiveContainer width="100%" height={150}>
            <LineChart data={SLEEP_STAGE_DATA}>
              <XAxis dataKey="time" tick={{ fill: '#6b7280', fontSize: 10 }} axisLine={false} tickLine={false} />
              <YAxis hide domain={[0, 3]} />
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(165,180,252,0.08)" />
              <Tooltip content={<CustomTooltip />} />
              <Line type="stepAfter" dataKey="stage" stroke="#6366f1" strokeWidth={2.5} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Snore Detection Chart */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">Snore Detection</h3>
          <span className="badge badge-warning">High at 3 AM</span>
        </div>
        <div className="glass-card-sm" style={{ padding: '16px' }}>
          <ResponsiveContainer width="100%" height={140}>
            <AreaChart data={SNORE_DATA}>
              <defs>
                <linearGradient id="snoreGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f87171" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="#f87171" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="time" tick={{ fill: '#6b7280', fontSize: 10 }} axisLine={false} tickLine={false} />
              <YAxis hide />
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(165,180,252,0.08)" />
              <Tooltip content={<CustomTooltip />} />
              <ReferenceLine y={50} stroke="#f87171" strokeDasharray="4 4" label={{ value: 'High', fill: '#f87171', fontSize: 10 }} />
              <Area type="monotone" dataKey="level" stroke="#f87171" strokeWidth={2} fill="url(#snoreGrad)" name="Noise dB" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Sleep Debt / Efficiency */}
      <div style={{ padding: '0 20px' }}>
        <div className="section-header">
          <h3 className="section-title">Sleep Debt</h3>
          <span className="badge badge-accent">Stable</span>
        </div>
        <div className="glass-card-sm" style={{ padding: '16px' }}>
          <ResponsiveContainer width="100%" height={140}>
            <AreaChart data={SLEEP_DEBT_DATA}>
              <defs>
                <linearGradient id="actualGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6366f1" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="day" tick={{ fill: '#6b7280', fontSize: 10 }} axisLine={false} tickLine={false} />
              <YAxis hide domain={[5, 10]} />
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(165,180,252,0.08)" />
              <Tooltip content={<CustomTooltip />} />
              <ReferenceLine y={8} stroke="#34d399" strokeDasharray="4 4" label={{ value: 'Goal', fill: '#34d399', fontSize: 10 }} />
              <Area type="monotone" dataKey="actual" stroke="#6366f1" strokeWidth={2} fill="url(#actualGrad)" name="Hours" />
            </AreaChart>
          </ResponsiveContainer>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12 }}>
            {[{ label: 'Avg Duration', value: '7h 14m', color: '#818cf8' },
              { label: 'Efficiency', value: '91%', color: '#34d399' },
              { label: 'Deficit', value: '-46m', color: '#f97316' }].map(s => (
              <div key={s.label} style={{ textAlign: 'center' }}>
                <p style={{ fontFamily: 'Outfit', fontSize: '1.1rem', fontWeight: 700, color: s.color }}>{s.value}</p>
                <p style={{ fontSize: '0.7rem', color: '#6b7280' }}>{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
