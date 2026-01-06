const { WebhookReceiver } = require('livekit-server-sdk');
const admin = require("firebase-admin");

// --- 1. AUTH SETUP ---
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

// --- 2. HANDLER ---
exports.handler = async function(event, context) {
  // Only allow POST requests
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  const receiver = new WebhookReceiver(apiKey, apiSecret);

  try {
    const body = event.body;
    const authHeader = event.headers['authorization'] || event.headers['Authorization'];

    if (!authHeader) {
      console.warn("⚠️ Missing Authorization Header");
      return { statusCode: 401, body: 'Missing Signature' };
    }

    // Verify the event comes from LiveKit
    const webhookEvent = await receiver.receive(body, authHeader);
    const roomName = webhookEvent.room?.name;

    if (!roomName) {
      return { statusCode: 200, body: 'No room name in event' };
    }

    // REFERENCE: Matches your collection name 'rooms'
    const roomRef = db.collection('rooms').doc(roomName);
    const numParticipants = webhookEvent.room.numParticipants || 0;

    console.log(`Event: ${webhookEvent.event} | Room: ${roomName} | Count: ${numParticipants}`);

    // --- LOGIC: ROOM FINISHED ---
    if (webhookEvent.event === 'room_finished') {
      console.log(`🏁 Room ${roomName} finished. Marking as inactive.`);
      
      // We do NOT delete here. We just hide it from the app.
      await roomRef.update({
        memberCount: 0,
        isActive: false, // <--- This hides it from your Flutter App filter
        endedAt: admin.firestore.FieldValue.serverTimestamp()
      }).catch(err => {
         // Ignore "Not Found" errors (code 5) if the room was already deleted
         if (err.code !== 5) console.error(`⚠️ Update failed: ${err.message}`);
      });
    } 
    
    // --- LOGIC: PARTICIPANT UPDATE ---
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