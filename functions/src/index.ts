import { onCall, HttpsError } from "firebase-functions/v2/https";
import { AccessToken } from "livekit-server-sdk";
import * as logger from "firebase-functions/logger";

// 1. Get keys from process.env (Loaded automatically from your .env file)
const API_KEY = process.env.LIVEKIT_API_KEY;
const API_SECRET = process.env.LIVEKIT_API_SECRET;

export const generateLiveKitToken = onCall(async (request) => {
  // 2. Fix: In v2, 'request' contains both 'data' and 'auth'
  // Check if API Keys are loaded
  if (!API_KEY || !API_SECRET) {
    logger.error("LiveKit keys are missing from .env file");
    throw new HttpsError("internal", "Server configuration error");
  }

  // 3. Security: Check if user is logged in
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  // Extract data from the request
  const roomId = request.data.roomId;
  const username = request.data.username || "User";
  
  // Use Firebase UID as the unique identity for LiveKit
  const participantIdentity = request.auth.uid;

  if (!roomId) {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with a 'roomId'."
    );
  }

  try {
    // 4. Generate the Token
    const at = new AccessToken(API_KEY, API_SECRET, {
      identity: participantIdentity,
      name: username,
    });

    // Grant permissions
    at.addGrant({
      roomJoin: true,
      room: roomId,
      canPublish: true,
      canSubscribe: true,
    });

    // 5. Return the token
    return {
      token: await at.toJwt(),
    };
  } catch (error) {
    logger.error("Token generation failed", error);
    throw new HttpsError("internal", "Could not generate token");
  }
});