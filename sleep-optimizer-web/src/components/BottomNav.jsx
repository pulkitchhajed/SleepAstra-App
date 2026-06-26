import React from 'react';
import { useApp } from '../context/AppContext.jsx';
import './BottomNav.css';

const NAV_ITEMS = [
  { id: 'home', label: 'Home', icon: (active) => (
    <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2">
      <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
      <polyline points="9,22 9,12 15,12 15,22"/>
    </svg>
  )},
  { id: 'insights', label: 'Insights', icon: (active) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <line x1="18" y1="20" x2="18" y2="10"/>
      <line x1="12" y1="20" x2="12" y2="4"/>
      <line x1="6" y1="20" x2="6" y2="14"/>
    </svg>
  )},
  { id: 'sounds', label: 'Sounds', icon: (active) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M9 18V5l12-2v13"/>
      <circle cx="6" cy="18" r="3"/>
      <circle cx="18" cy="16" r="3"/>
    </svg>
  )},
  { id: 'profile', label: 'Profile', icon: (active) => (
    <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2">
      <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/>
      <circle cx="12" cy="7" r="4"/>
    </svg>
  )},
];

export default function BottomNav() {
  const { activeTab, setActiveTab } = useApp();

  return (
    <nav className="bottom-nav-bar" role="navigation" aria-label="Main Navigation">
      {NAV_ITEMS.map(item => (
        <button
          key={item.id}
          id={`nav-${item.id}`}
          className={`nav-btn ${activeTab === item.id ? 'active' : ''}`}
          onClick={() => setActiveTab(item.id)}
          aria-label={item.label}
        >
          <span className="nav-btn-icon">{item.icon(activeTab === item.id)}</span>
          <span className="nav-btn-label">{item.label}</span>
          {activeTab === item.id && <span className="nav-active-dot" />}
        </button>
      ))}
    </nav>
  );
}
