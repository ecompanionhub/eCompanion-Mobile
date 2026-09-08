export const MAX_ATTACHMENT_COUNT = 8;
export const MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024;
export const MAX_TURN_ATTACHMENT_BYTES = 25 * 1024 * 1024;

export function attachmentKind(mimeType) {
  const mime = String(mimeType || '').trim().toLowerCase();
  if (mime.startsWith('image/')) return 'image';
  if (mime.startsWith('audio/')) return 'audio';
  if (mime.startsWith('video/')) return 'video';
  return 'document';
}

export function normalizedMimeType(file) {
  const mime = String(file?.type || '').trim().toLowerCase();
  if (mime) return mime;
  return 'application/octet-stream';
}

export function validateAttachmentFiles(files) {
  const list = Array.from(files || []);
  if (list.length === 0) return list;
  if (list.length > MAX_ATTACHMENT_COUNT) {
    throw new Error(`Choose up to ${MAX_ATTACHMENT_COUNT} files at once.`);
  }

  let total = 0;
  for (const file of list) {
    const size = Number(file?.size || 0);
    if (!Number.isFinite(size) || size <= 0) throw new Error('One of the selected files is empty.');
    if (size > MAX_ATTACHMENT_BYTES) throw new Error(`${file?.name || 'A file'} is larger than 20 MB.`);
    total += size;
  }
  if (total > MAX_TURN_ATTACHMENT_BYTES) throw new Error('The selected files are larger than 25 MB together.');
  return list;
}

function bytesToBase64(bytes) {
  let binary = '';
  const chunk = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunk) {
    binary += String.fromCharCode(...bytes.subarray(offset, Math.min(offset + chunk, bytes.length)));
  }
  return btoa(binary);
}

function hexDigest(buffer) {
  return Array.from(new Uint8Array(buffer), byte => byte.toString(16).padStart(2, '0')).join('');
}

export async function prepareAttachment(file, { cryptoImpl = globalThis.crypto } = {}) {
  if (!cryptoImpl?.subtle) throw new Error('Secure attachment hashing is unavailable in this browser.');
  const [buffer, mimeType] = [await file.arrayBuffer(), normalizedMimeType(file)];
  const bytes = new Uint8Array(buffer);
  if (bytes.byteLength !== Number(file.size)) throw new Error('The selected file changed while it was being prepared.');
  const digest = await cryptoImpl.subtle.digest('SHA-256', buffer);
  return Object.freeze({
    id: `mobile:${cryptoImpl.randomUUID()}`,
    kind: attachmentKind(mimeType),
    filename: String(file.name || 'attachment'),
    mimeType,
    byteSize: bytes.byteLength,
    sha256: hexDigest(digest),
    dataBase64: bytesToBase64(bytes)
  });
}

export async function prepareAttachments(files, options) {
  const list = validateAttachmentFiles(files);
  const prepared = [];
  for (const file of list) prepared.push(await prepareAttachment(file, options));
  return Object.freeze(prepared);
}
