const admin = require('firebase-admin');

let firebaseApp;

if (!admin.apps.length) {
  try {
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId:    process.env.FIREBASE_PROJECT_ID,
        clientEmail:  process.env.FIREBASE_CLIENT_EMAIL,
        // Replace literal \n in env string with actual newlines
        privateKey:   process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      }),
    });
  } catch (err) {
    console.warn('⚠️  Firebase Admin SDK not initialized:', err.message);
    console.warn('   Push notifications will be disabled.');
    firebaseApp = null;
  }
} else {
  firebaseApp = admin.apps[0];
}

/**
 * Send a push notification to a single FCM token.
 * @param {string} token  - FCM device token
 * @param {string} title  - Notification title
 * @param {string} body   - Notification body
 * @param {object} data   - Optional data payload (key-value strings)
 */
const sendNotification = async (token, title, body, data = {}) => {
  if (!firebaseApp) return null;

  const message = {
    token,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  };

  try {
    const response = await admin.messaging().send(message);
    return response;
  } catch (err) {
    console.error('FCM send error:', err.message);
    return null;
  }
};

/**
 * Send to multiple tokens (multicast).
 * @param {string[]} tokens
 */
const sendMulticastNotification = async (tokens, title, body, data = {}) => {
  if (!firebaseApp || !tokens.length) return null;

  const message = {
    tokens,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    return response;
  } catch (err) {
    console.error('FCM multicast error:', err.message);
    return null;
  }
};

module.exports = { sendNotification, sendMulticastNotification };
