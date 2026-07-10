// functions/index.js
//
// Firebase Cloud Function: verifyAppleSubscription
//
// Called by the Flutter app immediately after a successful StoreKit purchase.
// Generates a signed JWT with the App Store Connect credentials, calls Apple's
// App Store Server API to verify the transaction, then writes the subscription
// record to Firestore.  The private key is stored in Firebase Secret Manager —
// never in the app binary.
//
// To set the secret before deploying:
//   firebase functions:secrets:set APPLE_IAP_PRIVATE_KEY
// Paste the full .p8 content (with real newlines) when prompted.
//
// For local emulator, create functions/.secret.local with:
//   APPLE_IAP_PRIVATE_KEY=<key with \n replaced by actual newlines>

'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const https = require('https');

admin.initializeApp();

const APPLE_IAP_PRIVATE_KEY = defineSecret('APPLE_IAP_PRIVATE_KEY');

// ── Apple credentials ─────────────────────────────────────────────────────────

const APPLE_ISSUER_ID  = '23e6f2ed-73aa-432a-9504-96b0290c7ac5';
const APPLE_KEY_ID     = '29MV66KM8Q';
// TODO: replace with the real bundle ID once provided.
const APPLE_BUNDLE_ID  = 'com.storybridge.app';

// ── Helpers ───────────────────────────────────────────────────────────────────

function generateAppleJWT(privateKey) {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      iss: APPLE_ISSUER_ID,
      iat: now,
      exp: now + 3600,
      aud: 'appstoreconnect-v1',
      bid: APPLE_BUNDLE_ID,
    },
    privateKey,
    {
      algorithm: 'ES256',
      header: { kid: APPLE_KEY_ID, typ: 'JWT' },
    }
  );
}

// Decodes the middle (payload) segment of a JWS without verifying the
// signature — safe because the response came from Apple's authenticated API.
function decodeJWSPayload(jwsToken) {
  const parts = jwsToken.split('.');
  if (parts.length !== 3) throw new Error('Invalid JWS format');
  return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
}

function httpsGet(url, bearerToken) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      { method: 'GET', headers: { Authorization: `Bearer ${bearerToken}` } },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => resolve({ status: res.statusCode, body: data }));
      }
    );
    req.on('error', reject);
    req.end();
  });
}

// ── Cloud Function ────────────────────────────────────────────────────────────

exports.verifyAppleSubscription = onCall(
  { secrets: [APPLE_IAP_PRIVATE_KEY], region: 'africa-south1' },
  async (request) => {
    const { transactionId, uid } = request.data;

    if (!transactionId || typeof transactionId !== 'string') {
      throw new HttpsError('invalid-argument', 'transactionId is required.');
    }
    if (!uid || typeof uid !== 'string') {
      throw new HttpsError('invalid-argument', 'uid is required.');
    }
    // Ensure the caller is the same user they claim to be.
    if (!request.auth || request.auth.uid !== uid) {
      throw new HttpsError('permission-denied', 'Caller UID does not match.');
    }

    // The secret may be stored with escaped newlines; normalise them.
    const privateKey = APPLE_IAP_PRIVATE_KEY.value().replace(/\\n/g, '\n');
    const appleToken = generateAppleJWT(privateKey);

    // Try production first, then sandbox (for TestFlight / development builds).
    const endpoints = [
      `https://api.storekit.itunes.apple.com/inApps/v2/transactions/${transactionId}`,
      `https://api.storekit-sandbox.itunes.apple.com/inApps/v2/transactions/${transactionId}`,
    ];

    let txPayload = null;
    let environment = null;

    for (let i = 0; i < endpoints.length; i++) {
      const { status, body } = await httpsGet(endpoints[i], appleToken);
      if (status === 200) {
        const data = JSON.parse(body);
        txPayload = decodeJWSPayload(data.signedTransactionInfo);
        environment = i === 0 ? 'Production' : 'Sandbox';
        break;
      }
    }

    if (!txPayload) {
      throw new HttpsError('not-found', 'Transaction not found or could not be verified with Apple.');
    }

    // Guard: confirm the transaction belongs to this app.
    if (txPayload.bundleId && txPayload.bundleId !== APPLE_BUNDLE_ID) {
      throw new HttpsError('permission-denied', 'Bundle ID mismatch.');
    }

    const db    = admin.firestore();
    const now   = admin.firestore.Timestamp.now();

    // Use the expiry date Apple returns; fall back to 30 days if absent
    // (non-renewable or old StoreKit 1 receipts may omit it).
    const expiresMs = txPayload.expiresDate
      ? Number(txPayload.expiresDate)
      : Date.now() + 30 * 24 * 60 * 60 * 1000;
    const endDate = admin.firestore.Timestamp.fromMillis(expiresMs);

    await db
      .collection('users')
      .doc(uid)
      .collection('subscriptions')
      .doc('current')
      .set(
        {
          planId:                txPayload.productId || APPLE_KEY_ID,
          planName:              'Premium',
          startDate:             now,
          endDate,
          status:                'active',
          uid,
          originalTransactionId: txPayload.originalTransactionId,
          transactionId:         txPayload.transactionId,
          environment,
          verifiedAt:            now,
        },
        { merge: true }
      );

    return { success: true, environment };
  }
);
