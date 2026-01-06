const admin = require("firebase-admin");

// --- AUTH SETUP ---
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
    return null;
  }
};

if (admin.apps.length === 0) {
  const serviceAccount = getServiceAccount();
  if (serviceAccount) {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  }
}

const db = admin.firestore();

exports.handler = async function(event, context) {
  try {
    console.log("🚀 Starting Daily Cleanup");

    // 1. GET CURRENT TIME (In Milliseconds)
    const now = Date.now();
    
    // 2. DEFINE CUTOFF (24 Hours Ago)
    const oneDayMillis = 24 * 60 * 60 * 1000;
    const cutoffMillis = now - oneDayMillis;

    console.log(`Current Time (ms): ${now}`);
    console.log(`Cutoff Time (ms):  ${cutoffMillis}`);

    // 3. QUERY (Comparing Number vs Number)
    // This looks for rooms where createdAt is SMALLER than the cutoff
    const snapshot = await db.collection('rooms')
      .where('createdAt', '<', cutoffMillis) 
      .get();

    if (snapshot.empty) {
      console.log("✅ No old rooms found to delete.");
      return { statusCode: 200, body: "No rooms to delete" };
    }

    // 4. DELETE
    const batch = db.batch();
    let count = 0;

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;
    });

    await batch.commit();

    console.log(`🗑️ Deleted ${count} old rooms.`);
    return { statusCode: 200, body: `Deleted ${count} rooms` };

  } catch (e) {
    console.error("❌ Cleanup Failed:", e);
    return { statusCode: 500, body: "Error" };
  }
};