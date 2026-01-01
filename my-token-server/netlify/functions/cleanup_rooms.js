const admin = require("firebase-admin");

// --- REUSE YOUR AUTH LOGIC HERE ---
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
  try {
    // 1. Calculate the cutoff time (24 hours ago)
    const cutoffTime = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const firebaseCutoff = admin.firestore.Timestamp.fromDate(cutoffTime);

    console.log(`🧹 Running Cleanup. Deleting rooms older than: ${cutoffTime.toISOString()}`);

    // 2. Query rooms where 'createdAt' is older than 24 hours
    // Make sure your rooms actually have a 'createdAt' field in Firestore!
    const snapshot = await db.collection('rooms')
      .where('createdAt', '<', firebaseCutoff)
      .get();

    if (snapshot.empty) {
      console.log("✅ No old rooms found.");
      return { statusCode: 200, body: "No rooms to delete" };
    }

    // 3. Batch delete
    const batch = db.batch();
    let count = 0;

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;
    });

    await batch.commit();

    console.log(`🗑️ Successfully deleted ${count} old rooms.`);
    return { statusCode: 200, body: `Deleted ${count} rooms` };

  } catch (e) {
    console.error("❌ Cleanup Error:", e);
    return { statusCode: 500, body: "Cleanup Failed" };
  }
};