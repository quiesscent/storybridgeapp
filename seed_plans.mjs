// seed_plans.mjs
// Seeds the Firestore `plans` collection and marks 2 stories as premium.
// Uses the Firebase CLI cached access token — no service account needed.

import { readFileSync } from 'fs';
import { homedir } from 'os';

const PROJECT_ID = 'storybridge-e4b5e';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── Read access token from firebase-tools cache ───────────────────────────────
const config = JSON.parse(readFileSync(`${homedir()}/.config/configstore/firebase-tools.json`, 'utf8'));
let ACCESS_TOKEN = config.tokens?.access_token ?? '';

// Get a fresh access token via `firebase login --reauth` output
// or use the `gcloud auth print-access-token` approach
async function refreshToken() {
  // Use `firebase` CLI itself to print a fresh token via a lightweight call
  const { execSync } = await import('child_process');
  try {
    // firebase-tools stores a refresh token — call gcloud implicitly through CLI
    // Cheapest route: use the firebase token:print equivalent
    const out = execSync(
      `node -e "const c=require(require('os').homedir()+'/.config/configstore/firebase-tools.json');` +
      `const r=c.tokens?.refresh_token;` +
      `fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:c.client_id||'563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',client_secret:c.client_secret||'j9iVZfS8ggCygyzNCn-ePzvE',refresh_token:r,grant_type:'refresh_token'})})` +
      `.then(r=>r.json()).then(d=>console.log(d.access_token||''))"`,
      { encoding: 'utf8', timeout: 10000 }
    ).trim();
    if (out && out.startsWith('ya29.')) {
      ACCESS_TOKEN = out;
      console.log('✓ Token refreshed');
    } else {
      console.log('Using cached access token');
    }
  } catch {
    console.log('Using cached access token');
  }
}

// ── Firestore helpers ─────────────────────────────────────────────────────────

function toFirestoreValue(v) {
  if (typeof v === 'string')  return { stringValue: v };
  if (typeof v === 'number')  return { integerValue: String(v) };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Array.isArray(v))       return { arrayValue: { values: v.map(toFirestoreValue) } };
  if (v && typeof v === 'object') {
    const fields = {};
    for (const [k, val] of Object.entries(v)) fields[k] = toFirestoreValue(val);
    return { mapValue: { fields } };
  }
  return { nullValue: null };
}

function toFirestoreDoc(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) fields[k] = toFirestoreValue(v);
  return { fields };
}

async function upsertDocument(collection, docId, data) {
  const fields = toFirestoreDoc(data).fields;
  // Each field path must be a separate query param
  const maskParams = Object.keys(fields)
    .map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`)
    .join('&');
  const url = `${BASE}/${collection}/${docId}?${maskParams}`;
  const resp = await fetch(url, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${ACCESS_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`upsertDocument ${collection}/${docId} failed: ${resp.status} ${err}`);
  }
  return resp.json();
}

async function listDocuments(collection) {
  const url = `${BASE}/${collection}?pageSize=20`;
  const resp = await fetch(url, { headers: { Authorization: `Bearer ${ACCESS_TOKEN}` } });
  if (!resp.ok) throw new Error(`listDocuments ${collection} failed: ${resp.status}`);
  const data = await resp.json();
  return data.documents ?? [];
}

// ── Plans data ────────────────────────────────────────────────────────────────

const PLANS = [
  {
    id: 'monthly',
    data: {
      name: 'Monthly',
      price: '£4.99/month',
      durationDays: 30,
      features: [
        'Unlimited premium stories',
        'HD video recordings',
        'Cloud backup for all stories',
        'Family sharing (up to 3 members)',
      ],
    },
  },
  {
    id: 'annual',
    data: {
      name: 'Annual',
      price: '£39.99/year',
      durationDays: 365,
      features: [
        'Everything in Monthly',
        'Save 33% vs monthly billing',
        'Priority customer support',
        'Early access to new stories',
        'Family sharing (up to 5 members)',
      ],
    },
  },
  {
    id: 'family',
    data: {
      name: 'Family',
      price: '£59.99/year',
      durationDays: 365,
      features: [
        'Everything in Annual',
        'Up to 10 family members',
        'Shared story library',
        'Dedicated family space',
        'Downloadable stories for offline use',
      ],
    },
  },
];

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  await refreshToken();

  // 1. Seed plans
  console.log('\n📚 Seeding plans collection...');
  for (const plan of PLANS) {
    await upsertDocument('plans', plan.id, plan.data);
    console.log(`  ✓ plans/${plan.id} — ${plan.data.name} (${plan.data.price})`);
  }

  // 2. Fetch existing stories and mark the first 2 as premium
  console.log('\n🔒 Marking stories as premium...');
  const storyDocs = await listDocuments('stories');
  if (storyDocs.length === 0) {
    console.log('  ⚠ No stories found in Firestore — skipping premium status update');
  } else {
    // Pick first 2 stories with active=true
    const active = storyDocs.filter(doc => {
      const fields = doc.fields ?? {};
      return fields.active?.booleanValue === true;
    });

    const toMark = active.slice(0, 2);
    for (const doc of toMark) {
      const docId = doc.name.split('/').pop();
      const title = doc.fields?.title?.stringValue ?? docId;
      await upsertDocument('stories', docId, { status: 'premium' });
      console.log(`  ✓ stories/${docId} ("${title}") → status: "premium"`);
    }

    // Ensure remaining stories explicitly have status: "free"
    const toFree = active.slice(2);
    for (const doc of toFree) {
      const docId = doc.name.split('/').pop();
      await upsertDocument('stories', docId, { status: 'free' });
    }
    console.log(`  ✓ ${toFree.length} other stories set to status: "free"`);
  }

  console.log('\n✅ Seed complete!');
  console.log('   Plans seeded:', PLANS.map(p => p.id).join(', '));
}

main().catch(err => { console.error('❌ Seed failed:', err.message); process.exit(1); });
