const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.processScheduledNotifications = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = new Date();
  const nowTime = now.getTime();
  
  const querySnapshot = await db.collection('scheduled_notifications')
    .where('status', 'in', ['pending', 'recurring'])
    .get();

  const promises = [];

  querySnapshot.forEach((doc) => {
    const data = doc.data();
    let shouldSend = false;

    if (data.status === 'recurring' && data.recurringWeekdays && data.recurringWeekdays.length > 0 && data.scheduledTimeOfDay) {
      // Calculate local time using client offset
      const offsetMs = (data.clientTimezoneOffset || 0) * 60 * 1000;
      const localNow = new Date(nowTime + offsetMs);
      
      const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      const currentDayName = dayNames[localNow.getUTCDay()];
      
      if (data.recurringWeekdays.includes(currentDayName)) {
        const [hourStr, minStr] = data.scheduledTimeOfDay.split(':');
        const hour = parseInt(hourStr, 10);
        const min = parseInt(minStr, 10);
        
        // Time window of 1 minute
        if (localNow.getUTCHours() === hour && localNow.getUTCMinutes() === min) {
          let lastSentMs = 0;
          if (data.lastSentAt) {
            lastSentMs = data.lastSentAt.toDate().getTime();
          }
          // Prevent multiple sends in the same minute
          if (nowTime - lastSentMs > 5 * 60 * 1000) {
            shouldSend = true;
          }
        }
      }
    } else if (data.scheduledTime) {
      // New Admin Dashboard format
      const scheduledTimeMs = data.scheduledTime.toDate().getTime();
      if (nowTime >= scheduledTimeMs) {
        shouldSend = true;
      }
    } else if (data.scheduleType === 'now') {
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
    } else if (data.status === 'pending' && (!data.recurringWeekdays || data.recurringWeekdays.length === 0)) {
      // Fallback for "Send now" notifications from older cached web clients that omitted scheduledTime
      shouldSend = true;
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

    // Attach banner image if present
    if (data.bannerImageUrl) {
      message.notification.image = data.bannerImageUrl;
    }
    
    // Attach custom payload data
    if (data.onTapAction) {
      message.data.onTapAction = data.onTapAction;
    }

    if (data.targetAudience) {
      // New admin dashboard targeting
      if (data.targetAudience === 'Premium users only') {
        message.topic = 'premium_users';
      } else if (data.targetAudience === 'Unsubscribed users') {
        message.topic = 'unsubscribed_users';
      } else {
        message.topic = 'all_users';
      }
      await admin.messaging().send(message);
    } else if (data.targetUid === 'all') {
      // Legacy targeting
      message.topic = 'all_users';
      await admin.messaging().send(message);
    } else if (data.fcmToken) {
      message.token = data.fcmToken;
      await admin.messaging().send(message);
    } else if (data.targetUid) {
      const userDoc = await db.collection('users').doc(data.targetUid).get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        message.token = userDoc.data().fcmToken;
        await admin.messaging().send(message);
      } else {
        throw new Error('No FCM Token found for user');
      }
    } else {
      throw new Error('No target specified for notification');
    }

    const isRecurring = data.status === 'recurring';
    if (isRecurring) {
      await db.collection('scheduled_notifications').doc(docId).update({
        lastSentAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } else {
      await db.collection('scheduled_notifications').doc(docId).update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    console.log(`Notification sent for doc: ${docId}`);
  } catch (error) {
    console.error(`Error sending notification ${docId}:`, error);
    await db.collection('scheduled_notifications').doc(docId).update({
      status: 'error',
      error: error.message
    });
  }
}
