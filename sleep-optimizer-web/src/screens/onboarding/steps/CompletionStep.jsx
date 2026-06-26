import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import { useApp } from '../../../context/AppContext.jsx';

export default function CompletionStep() {
  const { goToMain } = useApp();

  return (
    <div style={{display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',
      minHeight:'calc(100vh - 100px)',gap:28,textAlign:'center',padding:'0 10px'}}>

      <motion.div
        initial={{ scale: 0 }}
        animate={{ scale: 1 }}
        transition={{ type: 'spring', stiffness: 260, damping: 20, delay: 0.2 }}
        style={{position:'relative'}}
      >
        <div style={{
          width:120,height:120,borderRadius:'50%',
          background:'radial-gradient(circle, rgba(52,211,153,0.25), transparent 70%)',
          display:'flex',alignItems:'center',justifyContent:'center',
          boxShadow:'0 0 40px rgba(52,211,153,0.4)',
        }}>
          <span style={{fontSize:'4rem'}}>✅</span>
        </div>
        {[0,1,2,3,4,5].map(i => (
          <motion.div key={i}
            initial={{ opacity: 0, scale: 0 }}
            animate={{ opacity: [0, 1, 0], scale: [0, 1.5, 0], x: Math.cos(i*60*Math.PI/180)*60, y: Math.sin(i*60*Math.PI/180)*60 }}
            transition={{ delay: 0.6 + i*0.1, duration: 1 }}
            style={{position:'absolute',top:'50%',left:'50%',width:6,height:6,borderRadius:'50%',
              background:'#34d399',marginTop:-3,marginLeft:-3}}
          />
        ))}
      </motion.div>

      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.5 }}>
        <h2 style={{fontFamily:'Outfit',fontSize:'2rem',fontWeight:800,color:'#f0f0ff',marginBottom:12}}>
          You're all set! 🌙
        </h2>
        <p style={{color:'#a5b4fc',fontSize:'1rem',lineHeight:1.7,maxWidth:280}}>
          Your personalized sleep profile is ready. Let's start your journey to better sleep.
        </p>
      </motion.div>

      <motion.div
        style={{width:'100%',maxWidth:320,display:'flex',flexDirection:'column',gap:12}}
        initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.8 }}
      >
        <button id="btn-completion-start" className="btn-primary" style={{width:'100%',padding:18,fontSize:'1.05rem'}}
          onClick={goToMain}>
          Start Optimizing Sleep ✨
        </button>
      </motion.div>
    </div>
  );
}
