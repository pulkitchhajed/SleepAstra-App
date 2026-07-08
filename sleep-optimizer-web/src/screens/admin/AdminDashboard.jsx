import React, { useState, useEffect } from 'react';
import { collection, getDocs, addDoc, serverTimestamp } from 'firebase/firestore';
import { getAuth, signInWithEmailAndPassword, onAuthStateChanged, signOut } from 'firebase/auth';
import { db } from '../../firebaseConfig';
import './AdminDashboard.css';

export default function AdminDashboard() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [formData, setFormData] = useState({
    title: '',
    body: '',
    targetUid: 'all',
    scheduleType: 'now', // now, timer, bedtime
    timerMinutes: 10,
    bedtimeOffset: -60, // minutes (e.g. -60 = 1 hr before)
  });
  const [sending, setSending] = useState(false);
  const [message, setMessage] = useState('');
  
  const [user, setUser] = useState(null);
  const [authEmail, setAuthEmail] = useState('');
  const [authPassword, setAuthPassword] = useState('');

  useEffect(() => {
    const auth = getAuth();
    const unsubscribe = onAuthStateChanged(auth, (u) => {
      setUser(u);
      if (u) {
        fetchUsers();
      } else {
        setLoading(false);
      }
    });
    return () => unsubscribe();
  }, []);

  const fetchUsers = async () => {
    try {
      const snap = await getDocs(collection(db, 'users'));
      const fetchedUsers = [];
      snap.forEach(doc => {
        const data = doc.data();
        if (data.fcmToken) {
          fetchedUsers.push({ id: doc.id, ...data });
        }
      });
      setUsers(fetchedUsers);
    } catch (err) {
      console.error('Error fetching users:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSend = async (e) => {
    e.preventDefault();
    setSending(true);
    setMessage('');

    try {
      const payload = {
        title: formData.title,
        body: formData.body,
        targetUid: formData.targetUid,
        scheduleType: formData.scheduleType,
        status: 'pending',
        createdAt: serverTimestamp(),
      };

      if (formData.targetUid !== 'all') {
        const user = users.find(u => u.id === formData.targetUid);
        if (user) {
          payload.fcmToken = user.fcmToken;
          payload.bedtime = user.bedtime || '22:30';
        }
      }

      if (formData.scheduleType === 'timer') {
        payload.timerMinutes = Number(formData.timerMinutes);
      } else if (formData.scheduleType === 'bedtime') {
        payload.bedtimeOffsetMinutes = Number(formData.bedtimeOffset);
      }

      await addDoc(collection(db, 'scheduled_notifications'), payload);
      setMessage('Notification scheduled successfully!');
      setFormData(prev => ({ ...prev, title: '', body: '' }));
    } catch (err) {
      console.error('Error scheduling notification:', err);
      setMessage('Failed to schedule notification.');
    } finally {
      setSending(false);
    }
  };

  if (loading) {
    return <div className="admin-loading">Loading...</div>;
  }

  if (!user) {
    return (
      <div className="admin-dashboard">
        <div className="admin-header">
          <h1>Admin Login</h1>
          <p>Please authenticate to access the admin panel.</p>
        </div>
        <div className="admin-content">
          <form className="admin-form" onSubmit={(e) => {
            e.preventDefault();
            signInWithEmailAndPassword(getAuth(), authEmail, authPassword)
              .catch(err => setMessage(err.message));
          }}>
            <div className="form-group">
              <label>Email</label>
              <input type="email" value={authEmail} onChange={e => setAuthEmail(e.target.value)} required />
            </div>
            <div className="form-group">
              <label>Password</label>
              <input type="password" value={authPassword} onChange={e => setAuthPassword(e.target.value)} required />
            </div>
            <button type="submit" className="submit-btn">Login</button>
            {message && <div className="form-message" style={{borderColor: 'red'}}>{message}</div>}
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="admin-dashboard">
      <div className="admin-header" style={{display: 'flex', justifyContent: 'space-between'}}>
        <div>
          <h1>Admin Dashboard</h1>
          <p>Push Notifications Manager</p>
        </div>
        <button onClick={() => signOut(getAuth())} className="submit-btn" style={{width: 'auto', padding: '10px 20px', marginTop: 0}}>Logout</button>
      </div>

      <div className="admin-content">
        <form onSubmit={handleSend} className="admin-form">
          <div className="form-group">
            <label>Target User</label>
            <select
              value={formData.targetUid}
              onChange={(e) => setFormData({ ...formData, targetUid: e.target.value })}
            >
              <option value="all">All Users</option>
              {users.map(u => (
                <option key={u.id} value={u.id}>
                  {u.email || u.name || 'Anonymous'} ({u.id.substring(0, 5)}...) - Bedtime: {u.bedtime || 'N/A'}
                </option>
              ))}
            </select>
          </div>

          <div className="form-group">
            <label>Notification Title</label>
            <input
              type="text"
              required
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              placeholder="e.g. Time for bed!"
            />
          </div>

          <div className="form-group">
            <label>Notification Body</label>
            <textarea
              required
              value={formData.body}
              onChange={(e) => setFormData({ ...formData, body: e.target.value })}
              placeholder="e.g. Don't forget to turn on your sleep tracker."
              rows={3}
            />
          </div>

          <div className="form-group">
            <label>Schedule Delivery</label>
            <select
              value={formData.scheduleType}
              onChange={(e) => setFormData({ ...formData, scheduleType: e.target.value })}
            >
              <option value="now">Send Now (or within 1 min)</option>
              <option value="timer">Custom Timer</option>
              <option value="bedtime">Relative to Bedtime</option>
            </select>
          </div>

          {formData.scheduleType === 'timer' && (
            <div className="form-group">
              <label>Delay in Minutes</label>
              <input
                type="number"
                min="1"
                value={formData.timerMinutes}
                onChange={(e) => setFormData({ ...formData, timerMinutes: e.target.value })}
              />
            </div>
          )}

          {formData.scheduleType === 'bedtime' && (
            <div className="form-group">
              <label>Offset from Bedtime (Minutes)</label>
              <p className="help-text">E.g. -60 for 1 hour before, 0 for exactly at bedtime, 30 for 30 min after.</p>
              <input
                type="number"
                value={formData.bedtimeOffset}
                onChange={(e) => setFormData({ ...formData, bedtimeOffset: e.target.value })}
              />
            </div>
          )}

          <button type="submit" disabled={sending} className="submit-btn">
            {sending ? 'Scheduling...' : 'Schedule Notification'}
          </button>

          {message && <div className="form-message">{message}</div>}
        </form>
      </div>
    </div>
  );
}
