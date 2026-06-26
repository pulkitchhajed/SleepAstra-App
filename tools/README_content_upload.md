# Firestore Content Upload

This tool uploads blog and video documents into the collections used by the app:

- `blogs`
- `videos`

## Install

Run this once from the project root:

```bash
npm install --prefix tools
```

## Prepare Credentials

Create a Firebase Admin service account key in Firebase Console:

Project settings -> Service accounts -> Generate new private key.

Keep that JSON file outside source control.

## Edit Content

Use `tools/content_upload_template.json` as the upload format.

Blog fields:

```json
{
  "id": "optional-stable-doc-id",
  "title": "Blog title",
  "summary": "Short preview text",
  "content": "Markdown blog body",
  "coverImageUrl": "https://example.com/image.jpg",
  "category": "Sleep Tips",
  "author": "SnoreClinics Team",
  "readTimeMinutes": 5,
  "tags": ["sleep", "snoring"],
  "uploadedBy": "admin-script",
  "createdAt": "2026-06-25T00:00:00.000Z"
}
```

Video fields:

```json
{
  "id": "optional-stable-doc-id",
  "title": "Video title",
  "description": "Video description",
  "videoUrl": "https://example.com/video.mp4",
  "thumbnailUrl": "https://example.com/thumb.jpg",
  "tags": ["breathing", "sleep"],
  "uploadedBy": "admin-script",
  "createdAt": "2026-06-25T00:00:00.000Z"
}
```

## Upload

Validate first:

```bash
node tools/upload_firestore_content.js --dry-run --data tools/content_upload_template.json
```

Upload:

```bash
node tools/upload_firestore_content.js --service-account path/to/serviceAccountKey.json --data tools/content_upload_template.json
```

By default, existing documents are merged. Use `--replace` to overwrite whole documents.
