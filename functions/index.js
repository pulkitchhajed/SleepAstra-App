const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.processScheduledNotifications = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = new Date();
  const nowTime = now.getTime();
  
  const querySnapshot = await db.collection('scheduled_notifications')
    .where('status', '==', 'pending')
    .get();

  const promises = [];

  querySnapshot.forEach((doc) => {
    const data = doc.data();
    let shouldSend = false;

    if (data.scheduleType === 'now') {
      shouldSend = true;
    } else if (data.scheduleType === 'timer') {
      const createdTime = data.createdAt ? data.createdAt.toDate().getTime() : 0;
      const targetTime = createdTime + (data.timerMinutes * 60 * 1000);
      if (nowTime >= targetTime) {
        shouldSend = true;
      }
    } else if (data.scheduleType === 'bedtime') {
      // Bedtime format is like "22:30"
      if (data.bedtime) {
        const [hours, mins] = data.bedtime.split(':').map(Number);
        
        // Calculate bedtime today
        let targetBedtime = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hours, mins, 0);
        
        // Offset
        const offsetMs = (data.bedtimeOffsetMinutes || 0) * 60 * 1000;
        targetBedtime = new Date(targetBedtime.getTime() + offsetMs);

        // Send if it is within a 5-minute window after the target time
        // or if it's already past it (but only if it hasn't been sent yet, handled by pending status)
        if (nowTime >= targetBedtime.getTime()) {
          shouldSend = true;
        }
      } else {
        shouldSend = true; // Fallback
      }
    }

    if (shouldSend) {
      promises.push(sendNotification(doc.id, data));
    }
  });

  await Promise.all(promises);
  return null;
});

async function sendNotification(docId, data) {
  const db = admin.firestore();
  
  try {
    const message = {
      notification: {
        title: data.title,
        body: data.body
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    };

    if (data.targetUid === 'all') {
      message.topic = 'all_users';
      await admin.messaging().send(message);
    } else if (data.fcmToken) {
      message.token = data.fcmToken;
      await admin.messaging().send(message);
    } else {
      const userDoc = await db.collection('users').doc(data.targetUid).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        message.token = userDoc.data().fcmToken;
        await admin.messaging().send(message);
      } else {
        throw new Error('No FCM Token found for user');
      }
    }

    await db.collection('scheduled_notifications').doc(docId).update({
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`Notification sent for doc: ${docId}`);
  } catch (error) {
    console.error(`Error sending notification ${docId}:`, error);
    await db.collection('scheduled_notifications').doc(docId).update({
      status: 'error',
      error: error.message
    });
  }
}
