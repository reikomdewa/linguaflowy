// const { schedule } = require('@netlify/functions');
// const admin = require("firebase-admin");

// // 1. Initialize Firebase Admin (Reuse your existing logic)
// // We need to parse the ENV var safely
// const getServiceAccount = () => {
//   try {
//     if (typeof process.env.FIREBASE_SERVICE_ACCOUNT === 'object') {
//       return process.env.FIREBASE_SERVICE_ACCOUNT;
//     }
//     return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
//   } catch (e) {
//     console.error("Failed to parse Service Account", e);
//     return null;
//   }
// };

// if (admin.apps.length === 0) {
//   const serviceAccount = getServiceAccount();
//   if (serviceAccount) {
//     admin.initializeApp({
//       credential: admin.credential.cert(serviceAccount)
//     });
//   }
// }

// const db = admin.firestore();

// // 2. The Scheduled Handler
// const handler = async function(event, context) {
//   try {
//     console.log("Running room cleanup...");
    
//     // Calculate time 3 minutes ago
//     const now = Date.now();
//     const cutoffTime = now - (3 * 60 * 1000); 

//     // 3. Query rooms that have 0 members
//     // Note: This relies on your Flutter app updating 'memberCount' correctly.
//     const snapshot = await db.collection('rooms')
//       .where('memberCount', '==', 0)
//       .get();

//     if (snapshot.empty) {
//       console.log("No empty rooms found.");
//       return { statusCode: 200 };
//     }

//     const batch = db.batch();
//     let deleteCount = 0;

//     snapshot.forEach(doc => {
//       const data = doc.data();
      
//       // Determine the last activity time
//       // Prefer 'lastUpdatedAt', fallback to 'createdAt'
//       let lastActivityTime = 0;
      
//       if (data.lastUpdatedAt && data.lastUpdatedAt.toDate) {
//         lastActivityTime = data.lastUpdatedAt.toDate().getTime();
//       } else if (data.createdAt && data.createdAt.toDate) {
//         lastActivityTime = data.createdAt.toDate().getTime();
//       }

//       // If the room has been inactive for > 3 minutes, delete it
//       if (lastActivityTime < cutoffTime) {
//         console.log(`Deleting stale room: ${doc.id}`);
//         batch.delete(doc.ref);
//         deleteCount++;
//       }
//     });

//     if (deleteCount > 0) {
//       await batch.commit();
//       console.log(`Successfully deleted ${deleteCount} inactive rooms.`);
//     }

//     return { statusCode: 200 };
    
//   } catch (error) {
//     console.error("Cleanup Error:", error);
//     return { statusCode: 500 };
//   }
// };

// // 4. Export as a Scheduled Function
// // Cron syntax: "*/5 * * * *" means "Run every 5 minutes"
// exports.handler = schedule("*/5 * * * *", handler);