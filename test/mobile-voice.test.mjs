import assert from 'node:assert/strict';
import test from 'node:test';

import { createVoiceAdapter } from '../web/voice.js';

class FakeRecognition {
  constructor() {
    FakeRecognition.latest = this;
    this.onstart = null;
    this.onresult = null;
    this.onerror = null;
    this.onend = null;
  }

  start() {
    this.onstart?.();
  }

  stop() {
    this.onend?.();
  }
}

class FakeUtterance {
  constructor(text) {
    this.text = text;
    this.lang = '';
    this.rate = 1;
    this.pitch = 1;
    this.onstart = null;
    this.onend = null;
    this.onerror = null;
  }
}

test('starting owner speech while Lola is speaking cancels playback before listening', () => {
  const previousRecognition = globalThis.SpeechRecognition;
  const previousSynthesis = globalThis.speechSynthesis;
  const previousUtterance = globalThis.SpeechSynthesisUtterance;

  let cancelCount = 0;
  let activeUtterance = null;
  const states = [];

  globalThis.SpeechRecognition = FakeRecognition;
  globalThis.SpeechSynthesisUtterance = FakeUtterance;
  globalThis.speechSynthesis = {
    cancel() {
      cancelCount += 1;
      activeUtterance = null;
    },
    speak(utterance) {
      activeUtterance = utterance;
      utterance.onstart?.();
    }
  };

  try {
    const adapter = createVoiceAdapter({
      language: 'en-US',
      onState: state => states.push(state)
    });

    assert.equal(adapter.speak('Working on it'), true);
    assert.equal(adapter.isSpeaking(), true);
    const cancelAfterSpeakStart = cancelCount;

    assert.equal(adapter.toggleListening(), true);
    assert.equal(adapter.isSpeaking(), false);
    assert.equal(adapter.isListening(), true);
    assert.ok(cancelCount > cancelAfterSpeakStart, 'owner barge-in should cancel current Lola playback');
    assert.equal(activeUtterance, null);
    assert.equal(states.at(-1)?.text, 'Listening…');

    adapter.stopListening();
    assert.equal(adapter.isListening(), false);
  } finally {
    if (previousRecognition === undefined) delete globalThis.SpeechRecognition;
    else globalThis.SpeechRecognition = previousRecognition;
    if (previousSynthesis === undefined) delete globalThis.speechSynthesis;
    else globalThis.speechSynthesis = previousSynthesis;
    if (previousUtterance === undefined) delete globalThis.SpeechSynthesisUtterance;
    else globalThis.SpeechSynthesisUtterance = previousUtterance;
  }
});

test('switching to Call discards pending dictation instead of sending a parallel chat turn', () => {
  const previous = globalThis.SpeechRecognition;
  globalThis.SpeechRecognition = FakeRecognition;
  const transcripts = [];
  const states = [];
  try {
    const adapter = createVoiceAdapter({ onTranscript: text => transcripts.push(text), onState: state => states.push(state) });
    adapter.toggleListening();
    const result = [{ transcript: 'unfinished dictation' }];
    result.isFinal = true;
    FakeRecognition.latest.onresult({ resultIndex: 0, results: [result] });
    adapter.stopListening({ discard: true });
    assert.deepEqual(transcripts, []);
    assert.equal(states.at(-1).text, 'Voice ready');
    assert.equal(adapter.isListening(), false);
  } finally {
    if (previous === undefined) delete globalThis.SpeechRecognition;
    else globalThis.SpeechRecognition = previous;
  }
});
