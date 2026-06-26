import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import './NidraTab.css';

const INITIAL_MESSAGES = [
  {
    id: 1,
    role: 'assistant',
    text: "Hi! I'm **Nidra**, your AI sleep coach. 🌙\n\nI am currently running in offline prototype mode without backend connectivity. Once connected to a live server and your real sleep data, I will provide personalized insights regarding:\n- **Sleep apnea** screening & advice\n- **Snoring** reduction techniques\n- **Sleep hygiene** best practices\n- **Personalized** bedtime routines\n\nTry sending a message to test the chat UI!",
  },
];

const QUICK_PROMPTS = [
  'Why do I snore?',
  'How to fall asleep faster?',
  'What is sleep apnea?',
  'Best bedtime routine?',
];

const MOCK_RESPONSES = {
  default: "I am a prototype UI right now. When connected to a real AI backend (like the Gemini API), I will answer this question dynamically based on your actual sleep data! 🚀",
  snor: "Once connected to your real audio data, I will analyze your snoring severity and provide personalized, science-backed solutions. For now, you're experiencing my prototype interface! 🎙️",
  apnea: "When I have access to your live STOP-BANG clinical screening data and sleep stage charts via a backend integration, I'll provide detailed OSA risk assessments. 🩺",
  faster: "I will generate custom, dynamic wind-down routines based on your heart-rate data and past sleep efficiency once my AI brain is hooked up! ✨",
  routine: "Currently, my responses are placeholders. In the final production app, I will analyze your historical sleep debt and suggest the exact minute you should start your bedtime routine. 🕰️",
};

function getResponse(text) {
  const lower = text.toLowerCase();
  if (lower.includes('snor')) return MOCK_RESPONSES.snor;
  if (lower.includes('apnea') || lower.includes('apnoea')) return MOCK_RESPONSES.apnea;
  if (lower.includes('faster') || lower.includes('fall asleep')) return MOCK_RESPONSES.faster;
  if (lower.includes('routine') || lower.includes('bedtime')) return MOCK_RESPONSES.routine;
  return MOCK_RESPONSES.default;
}

function renderMarkdown(text) {
  // Bold
  let html = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  // Bullet points
  html = html.replace(/^- (.+)$/gm, '<li>$1</li>');
  html = html.replace(/(<li>.*<\/li>)/gs, '<ul>$1</ul>');
  // Numbered lists
  html = html.replace(/^\d+\. (.+)$/gm, '<li>$1</li>');
  // Line breaks
  html = html.replace(/\n\n/g, '</p><p>');
  html = html.replace(/\n/g, '<br/>');
  return `<p>${html}</p>`;
}

export default function NidraTab() {
  const { setNidraOpen } = useApp();
  const [messages, setMessages] = useState(INITIAL_MESSAGES);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [listening, setListening] = useState(false);
  const bottomRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isTyping]);

  const sendMessage = (text) => {
    if (!text.trim()) return;
    const userMsg = { id: Date.now(), role: 'user', text: text.trim() };
    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsTyping(true);

    setTimeout(() => {
      const reply = { id: Date.now() + 1, role: 'assistant', text: getResponse(text) };
      setMessages(prev => [...prev, reply]);
      setIsTyping(false);
    }, 1400 + Math.random() * 600);
  };

  const handleVoice = () => {
    if (!('webkitSpeechRecognition' in window || 'SpeechRecognition' in window)) {
      alert('Voice input not supported in this browser.');
      return;
    }
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    const recognition = new SpeechRecognition();
    recognition.lang = 'en-US';
    recognition.onstart = () => setListening(true);
    recognition.onresult = (e) => {
      const transcript = e.results[0][0].transcript;
      setInput(transcript);
      setListening(false);
    };
    recognition.onerror = () => setListening(false);
    recognition.onend = () => setListening(false);
    recognition.start();
  };

  return (
    <div className="nidra-tab">
      {/* Header */}
      <div className="nidra-header glass-card-sm">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div className="nidra-avatar" style={{ background: 'transparent', padding: 0 }}>
            <img src="/Nidra.png" alt="Nidra" style={{ width: 40, height: 40, objectFit: 'contain' }} />
          </div>
          <div>
            <h3 style={{ fontFamily: 'Outfit', fontSize: '1.1rem', fontWeight: 700 }}>Nidra</h3>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
              <div style={{ width: 7, height: 7, borderRadius: '50%', background: '#34d399', boxShadow: '0 0 6px #34d399' }} />
              <span style={{ fontSize: '0.72rem', color: '#34d399' }}>Online · AI Coach</span>
            </div>
          </div>
        </div>
        <button 
          onClick={() => setNidraOpen(false)}
          style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(255,255,255,0.1)', border: 'none', color: '#f0f0ff', fontSize: '1.2rem', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}
        >
          ✕
        </button>
      </div>

      {/* Messages */}
      <div className="nidra-messages">
        <AnimatePresence initial={false}>
          {messages.map(msg => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, y: 10, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              transition={{ duration: 0.3 }}
              className={`nidra-bubble ${msg.role}`}
            >
              {msg.role === 'assistant' && (
                <div className="nidra-bubble-avatar">🤖</div>
              )}
              <div className={`nidra-bubble-content ${msg.role}`}
                dangerouslySetInnerHTML={{ __html: renderMarkdown(msg.text) }}
              />
            </motion.div>
          ))}
          {isTyping && (
            <motion.div key="typing" initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="nidra-bubble assistant">
              <div className="nidra-bubble-avatar">🤖</div>
              <div className="nidra-bubble-content assistant nidra-typing">
                <span /><span /><span />
              </div>
            </motion.div>
          )}
        </AnimatePresence>
        <div ref={bottomRef} />
      </div>

      {/* Quick Prompts */}
      {messages.length <= 1 && (
        <div className="nidra-quick-prompts">
          {QUICK_PROMPTS.map(q => (
            <button key={q} className="quick-prompt-chip" id={`quick-${q.replace(/\s/g,'-').toLowerCase()}`}
              onClick={() => sendMessage(q)}>
              {q}
            </button>
          ))}
        </div>
      )}

      {/* Input Bar */}
      <div className="nidra-input-bar glass-card-sm">
        <button
          id="btn-voice-input"
          className={`voice-btn ${listening ? 'listening' : ''}`}
          onClick={handleVoice}
          title="Voice input"
        >
          🎤
        </button>
        <input
          ref={inputRef}
          id="nidra-input"
          className="nidra-input"
          placeholder="Ask Nidra anything about sleep..."
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && sendMessage(input)}
        />
        <button
          id="btn-send-message"
          className="send-btn"
          onClick={() => sendMessage(input)}
          disabled={!input.trim() || isTyping}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="22" y1="2" x2="11" y2="13"/>
            <polygon points="22,2 15,22 11,13 2,9"/>
          </svg>
        </button>
      </div>
    </div>
  );
}
