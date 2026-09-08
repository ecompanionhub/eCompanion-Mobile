import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import test from 'node:test';

import {
  MAX_ATTACHMENT_BYTES,
  MAX_ATTACHMENT_COUNT,
  MAX_TURN_ATTACHMENT_BYTES,
  attachmentKind,
  prepareAttachment,
  validateAttachmentFiles
} from '../web/attachments.js';

if (typeof globalThis.btoa !== 'function') {
  globalThis.btoa = (value) => Buffer.from(value, 'binary').toString('base64');
}

function fakeFile({ name = 'note.txt', type = 'text/plain', bytes = new TextEncoder().encode('hello') } = {}) {
  const stableBytes = Uint8Array.from(bytes);
  return Object.freeze({
    name,
    type,
    size: stableBytes.byteLength,
    async arrayBuffer() {
      return stableBytes.buffer.slice(stableBytes.byteOffset, stableBytes.byteOffset + stableBytes.byteLength);
    }
  });
}

test('attachment kind follows Runtime multimodal families', () => {
  assert.equal(attachmentKind('image/png'), 'image');
  assert.equal(attachmentKind('audio/mpeg'), 'audio');
  assert.equal(attachmentKind('video/mp4'), 'video');
  assert.equal(attachmentKind('application/pdf'), 'document');
  assert.equal(attachmentKind('text/plain'), 'document');
});

test('attachment preparation produces canonical bytes, digest and metadata', async () => {
  const attachment = await prepareAttachment(fakeFile(), {
    cryptoImpl: {
      subtle: webcrypto.subtle,
      randomUUID: () => 'test-id'
    }
  });

  assert.deepEqual(attachment, {
    id: 'mobile:test-id',
    kind: 'document',
    filename: 'note.txt',
    mimeType: 'text/plain',
    byteSize: 5,
    sha256: '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
    dataBase64: 'aGVsbG8='
  });
});

test('attachment selection fails closed at Runtime-compatible limits', () => {
  const tiny = fakeFile({ bytes: new Uint8Array([1]) });
  assert.throws(
    () => validateAttachmentFiles(Array.from({ length: MAX_ATTACHMENT_COUNT + 1 }, () => tiny)),
    /up to 8 files/i
  );

  const oversized = Object.freeze({ name: 'huge.bin', type: 'application/octet-stream', size: MAX_ATTACHMENT_BYTES + 1 });
  assert.throws(() => validateAttachmentFiles([oversized]), /larger than 20 MB/i);

  const half = Math.floor(MAX_TURN_ATTACHMENT_BYTES / 2) + 1;
  const a = Object.freeze({ name: 'a.bin', type: 'application/octet-stream', size: half });
  const b = Object.freeze({ name: 'b.bin', type: 'application/octet-stream', size: half });
  assert.throws(() => validateAttachmentFiles([a, b]), /larger than 25 MB together/i);
});
