import { readFileSync } from "fs";
import { homedir } from "os";

const PROJECT_ID = "storybridge-e4b5e";
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const config = JSON.parse(
  readFileSync(`${homedir()}/.config/configstore/firebase-tools.json`, "utf8"),
);
let ACCESS_TOKEN = config.tokens?.access_token ?? "";

async function refreshToken() {
  const { execSync } = await import("child_process");
  try {
    const out = execSync(
      `node -e "const c=require(require('os').homedir()+'/.config/configstore/firebase-tools.json');` +
        `const r=c.tokens?.refresh_token;` +
        `fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:c.client_id||'563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',client_secret:c.client_secret||'j9iVZfS8ggCygyzNCn-ePzvE',refresh_token:r,grant_type:'refresh_token'})})` +
        `.then(r=>r.json()).then(d=>console.log(d.access_token||''))"`,
      { encoding: "utf8", timeout: 10000 },
    ).trim();
    if (out && out.startsWith("ya29.")) {
      ACCESS_TOKEN = out;
      console.log("✓ Token refreshed");
    }
  } catch {}
}

async function listDocuments(collection) {
  const url = `${BASE}/${collection}?pageSize=50`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${ACCESS_TOKEN.trim()}` },
  });
  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(
      `listDocuments ${collection} failed: ${resp.status} - ${errText}`,
    );
  }
  const data = await resp.json();
  return data.documents ?? [];
}

async function main() {
  await refreshToken();
  const docs = await listDocuments("stories");
  console.log(`Found ${docs.length} stories in Firestore:`);
  for (const doc of docs) {
    const id = doc.name.split("/").pop();
    const fields = doc.fields ?? {};
    console.log(`Story ID: ${id}`);
    console.log(`  Title: ${fields.title?.stringValue}`);
    console.log(`  Cover URL: ${fields.cover_url?.stringValue}`);
  }
}

main().catch(console.error);
