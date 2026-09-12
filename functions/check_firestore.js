const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function check() {
  const snapshot = await db.collection('scheduled_notifications').orderBy('createdAt', 'desc').limit(5).get();
  snapshot.forEach(doc => {
    console.log(doc.id, '=>', doc.data());
  });
}

check();
