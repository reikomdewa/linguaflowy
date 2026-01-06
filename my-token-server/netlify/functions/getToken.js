const { AccessToken } = require('livekit-server-sdk');

exports.handler = async function(event, context) {
  // CORS Headers (So your Flutter app can talk to this)
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
  };

  if (event.httpMethod === 'OPTIONS') return { statusCode: 200, headers, body: '' };

  // Get Params
  const { roomName, username } = event.queryStringParameters;

  if (!roomName || !username) {
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Missing params' }) };
  }

  // Get Keys from Environment
  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;

  if (!apiKey || !apiSecret) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: 'Server misconfigured' }) };
  }

  try {
    const at = new AccessToken(apiKey, apiSecret, { identity: username, name: username });
    at.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true });

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ token: await at.toJwt() })
    };
  } catch (e) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: e.message }) };
  }
};