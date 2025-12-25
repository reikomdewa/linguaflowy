const { WebhookReceiver } = require('livekit-server-sdk');
const admin = require("firebase-admin");

// 1. Initialize Firebase Admin (Outside handler to reuse connection)
if (admin.apps.length === 0) {
  // You must set these env vars in Netlify Dashboard
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

exports.handler = async function(event, context) {
  // Only allow POST requests
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  // 2. Get Keys from Env
  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  
  if (!apiKey || !apiSecret) {
    return { statusCode: 500, body: 'Server misconfigured' };
  }

  const receiver = new WebhookReceiver(apiKey, apiSecret);

  try {
    // 3. Verify and Decode the Webhook Event
    // event.body is the raw string payload
    // event.headers.authorization contains the signature
    const body = event.body;
    const authHeader = event.headers['authorization'] || event.headers['Authorization'];

    const webhookEvent = await receiver.receive(body, authHeader);

    // 4. Handle "room_finished"
    if (webhookEvent.event === 'room_finished') {
      const roomName = webhookEvent.room.name;
      console.log(`Room finished: ${roomName}. Deleting from Firestore...`);

      // DELETE THE ROOM DOCUMENT
      await db.collection('rooms').doc(roomName).delete();
      
      console.log(`Successfully deleted room: ${roomName}`);
    }

    return { statusCode: 200, body: 'ok' };

  } catch (e) {
    console.error("Error handling webhook:", e);
    return { statusCode: 401, body: 'Invalid Webhook Signature' };
  }
};