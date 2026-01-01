const { WebhookReceiver } = require('livekit-server-sdk');
const admin = require("firebase-admin");

const getServiceAccount = () => {
  try {
    if (typeof process.env.FIREBASE_SERVICE_ACCOUNT === 'object') {
      return process.env.FIREBASE_SERVICE_ACCOUNT;
    }
    const account = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    if (account.private_key) {
      account.private_key = account.private_key.replace(/\\n/g, '\n');
    }
    return account;
  } catch (e) {
    console.error("❌ Failed to parse FIREBASE_SERVICE_ACCOUNT", e);
    return null;
  }
};

if (admin.apps.length === 0) {
  const serviceAccount = getServiceAccount();
  if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  }
}

const db = admin.firestore();

exports.handler = async function(event, context) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  const receiver = new WebhookReceiver(apiKey, apiSecret);

  try {
    const body = event.body;
    const authHeader = event.headers['authorization'] || event.headers['Authorization'];

    if (!authHeader) return { statusCode: 401, body: 'Missing Signature' };

    const webhookEvent = await receiver.receive(body, authHeader);
    const roomName = webhookEvent.room?.name;

    if (!roomName) return { statusCode: 200, body: 'No room name' };

    const roomRef = db.collection('rooms').doc(roomName);
    const numParticipants = webhookEvent.room.numParticipants || 0;

    console.log(`Event: ${webhookEvent.event} | Room: ${roomName} | Count: ${numParticipants}`);

    if (webhookEvent.event === 'room_finished') {
      // 🛑 CHANGED: Do NOT delete. Just mark as empty/inactive.
      console.log(`🏁 Room ${roomName} finished. Marking as inactive...`);
      await roomRef.update({
        memberCount: 0,
        isActive: false, // Optional: helpful flag for your frontend filtering
        endedAt: admin.firestore.FieldValue.serverTimestamp()
      }).catch(err => {
         console.error(`⚠️ Update failed: ${err.message}`);
      });
    } 
    else if (webhookEvent.event === 'participant_joined' || webhookEvent.event === 'participant_left') {
      await roomRef.update({
        memberCount: numParticipants,
        lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      }).catch(err => {
         if (err.code !== 5) console.error(`⚠️ Update failed: ${err.message}`);
      });
    }

    return { statusCode: 200, body: 'ok' };

  } catch (e) {
    console.error("❌ Webhook Error:", e);
    return { statusCode: 500, body: 'Internal Error' };
  }
};