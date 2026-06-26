#!/usr/bin/env node

/**
 * Upload blog and video content into Firestore for SnoreClinics.
 *
 * Usage:
 *   node tools/upload_firestore_content.js \
 *     --service-account path/to/serviceAccountKey.json \
 *     --data tools/content_upload_template.json
 *
 * You can also use Application Default Credentials:
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\path\serviceAccountKey.json
 *   node tools/upload_firestore_content.js --data tools/content_upload_template.json
 */

const fs = require('fs');
const path = require('path');

let admin = null;

function loadAdmin() {
  if (admin) return admin;
  admin = require('firebase-admin');
  return admin;
}

function parseArgs(argv) {
  const args = {
    data: 'tools/content_upload_template.json',
    serviceAccount: null,
    projectId: null,
    dryRun: false,
    replace: false,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];

    if (arg === '--data') {
      args.data = next;
      i += 1;
    } else if (arg === '--service-account') {
      args.serviceAccount = next;
      i += 1;
    } else if (arg === '--project-id') {
      args.projectId = next;
      i += 1;
    } else if (arg === '--dry-run') {
      args.dryRun = true;
    } else if (arg === '--replace') {
      args.replace = true;
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

function printHelp() {
  console.log(`
Upload blogs and videos to Firestore.

Options:
  --data <file>              JSON file to upload. Default: tools/content_upload_template.json
  --service-account <file>   Firebase Admin service account JSON.
  --project-id <id>          Optional Firebase project id override.
  --dry-run                  Validate and print documents without uploading.
  --replace                  Replace whole documents instead of merging.

Examples:
  node tools/upload_firestore_content.js --service-account serviceAccountKey.json
  node tools/upload_firestore_content.js --dry-run --data tools/content_upload_template.json
`);
}

function readJson(filePath) {
  const absolute = path.resolve(filePath);
  if (!fs.existsSync(absolute)) {
    throw new Error(`File not found: ${absolute}`);
  }
  const text = fs.readFileSync(absolute, 'utf8').replace(/^\uFEFF/, '');
  return JSON.parse(text);
}

function initFirebase(args) {
  const firebaseAdmin = loadAdmin();
  if (firebaseAdmin.apps.length > 0) return;

  const options = {};
  if (args.projectId) {
    options.projectId = args.projectId;
  }

  if (args.serviceAccount) {
    const serviceAccount = readJson(args.serviceAccount);
    firebaseAdmin.initializeApp({
      credential: firebaseAdmin.credential.cert(serviceAccount),
      projectId: args.projectId || serviceAccount.project_id,
    });
    return;
  }

  firebaseAdmin.initializeApp(options);
}

function requireString(item, field, collection, index) {
  const value = item[field];
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${collection}[${index}].${field} must be a non-empty string`);
  }
  return value.trim();
}

function optionalString(item, field, fallback = '') {
  const value = item[field];
  return typeof value === 'string' ? value.trim() : fallback;
}

function stringArray(value, fieldName) {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    throw new Error(`${fieldName} must be an array of strings`);
  }
  return value.map((entry) => String(entry).trim()).filter(Boolean);
}

function intValue(value, fallback, fieldName) {
  if (value == null) return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`${fieldName} must be a non-negative integer`);
  }
  return parsed;
}

function createdAtValue(value) {
  if (value == null || value === '') {
    return { kind: 'serverTimestamp' };
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`createdAt must be an ISO date string, got: ${value}`);
  }
  return { kind: 'timestamp', value: date.toISOString() };
}

function firestoreCreatedAt(value) {
  const firebaseAdmin = loadAdmin();
  if (value && value.kind === 'timestamp') {
    return firebaseAdmin.firestore.Timestamp.fromDate(new Date(value.value));
  }
  return firebaseAdmin.firestore.FieldValue.serverTimestamp();
}

function materializeFirestoreData(data) {
  return {
    ...data,
    createdAt: firestoreCreatedAt(data.createdAt),
  };
}

function buildBlogDoc(item, index) {
  return {
    id: optionalString(item, 'id') || null,
    data: {
      title: requireString(item, 'title', 'blogs', index),
      content: requireString(item, 'content', 'blogs', index),
      summary: requireString(item, 'summary', 'blogs', index),
      coverImageUrl: optionalString(item, 'coverImageUrl'),
      category: requireString(item, 'category', 'blogs', index),
      author: requireString(item, 'author', 'blogs', index),
      readTimeMinutes: intValue(item.readTimeMinutes, 5, `blogs[${index}].readTimeMinutes`),
      tags: stringArray(item.tags, `blogs[${index}].tags`),
      uploadedBy: optionalString(item, 'uploadedBy', 'admin-script'),
      likes: stringArray(item.likes, `blogs[${index}].likes`),
      bookmarks: stringArray(item.bookmarks, `blogs[${index}].bookmarks`),
      createdAt: createdAtValue(item.createdAt),
    },
  };
}

function buildVideoDoc(item, index) {
  return {
    id: optionalString(item, 'id') || null,
    data: {
      title: requireString(item, 'title', 'videos', index),
      description: requireString(item, 'description', 'videos', index),
      videoUrl: requireString(item, 'videoUrl', 'videos', index),
      thumbnailUrl: requireString(item, 'thumbnailUrl', 'videos', index),
      tags: stringArray(item.tags, `videos[${index}].tags`),
      uploadedBy: optionalString(item, 'uploadedBy', 'admin-script'),
      likes: stringArray(item.likes, `videos[${index}].likes`),
      useful: stringArray(item.useful, `videos[${index}].useful`),
      createdAt: createdAtValue(item.createdAt),
    },
  };
}

async function uploadCollection(db, collectionName, docs, replace, dryRun) {
  if (!docs.length) {
    console.log(`No ${collectionName} to upload.`);
    return;
  }

  if (dryRun) {
    console.log(`\n[Dry run] ${collectionName}:`);
    for (const doc of docs) {
      console.log(`- ${doc.id || '(auto id)'}: ${doc.data.title}`);
    }
    return;
  }

  const batch = db.batch();
  for (const doc of docs) {
    const ref = doc.id
      ? db.collection(collectionName).doc(doc.id)
      : db.collection(collectionName).doc();
    batch.set(ref, materializeFirestoreData(doc.data), { merge: !replace });
  }

  await batch.commit();
  console.log(`Uploaded ${docs.length} ${collectionName}.`);
}

async function main() {
  const args = parseArgs(process.argv);
  const input = readJson(args.data);

  if (!Array.isArray(input.blogs || []) || !Array.isArray(input.videos || [])) {
    throw new Error('Input JSON must contain "blogs" and/or "videos" arrays.');
  }

  const blogs = (input.blogs || []).map(buildBlogDoc);
  const videos = (input.videos || []).map(buildVideoDoc);

  if (blogs.length === 0 && videos.length === 0) {
    throw new Error('Nothing to upload. Add items to "blogs" or "videos".');
  }

  if (!args.dryRun) {
    initFirebase(args);
  }

  const db = args.dryRun ? null : admin.firestore();
  await uploadCollection(db, 'blogs', blogs, args.replace, args.dryRun);
  await uploadCollection(db, 'videos', videos, args.replace, args.dryRun);
}

main().catch((error) => {
  console.error(`Upload failed: ${error.message}`);
  process.exit(1);
});
