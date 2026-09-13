export function createVoiceAdapter({ language, onTranscript, onState } = {}) {
  const Recognition = globalThis.SpeechRecognition || globalThis.webkitSpeechRecognition || null;
  const canSpeak = Boolean(globalThis.speechSynthesis && globalThis.SpeechSynthesisUtterance);
  const lang = String(language || globalThis.navigator?.language || 'en-US');

  let recognition = null;
  let listening = false;
  let speaking = false;
  let speakReplies = true;
  let discardTranscript = false;
  let conversationMode = false;
  let speechPending = false;
  let resumeTimer = null;
  let speechGeneration = 0;

  function emit(text) {
    onState?.({ listening, speaking, speakReplies, text });
  }

  function visibleForVoice() { return globalThis.document?.visibilityState !== 'hidden'; }
  function clearResumeTimer() { if (resumeTimer !== null) { globalThis.clearTimeout?.(resumeTimer); resumeTimer = null; } }
  function canAutoResume() { return conversationMode && visibleForVoice() && !listening && !speaking && !speechPending; }
  function scheduleResume(delay = 120) {
    clearResumeTimer();
    if (!Recognition || !canAutoResume()) return false;
    resumeTimer = globalThis.setTimeout?.(() => {
      resumeTimer = null;
      if (!canAutoResume()) return;
      try { beginListening(); } catch { conversationMode = false; emit('Voice restart unavailable'); }
    }, delay) ?? null;
    return true;
  }

  function capabilities() {
    return Object.freeze({
      speech_recognition: Boolean(Recognition),
      speech_synthesis: canSpeak
    });
  }

  function stopSpeaking({ emitState = true } = {}) {
    if (!canSpeak) return false;
    const wasSpeaking = speaking || speechPending;
    clearResumeTimer();
    speechGeneration += 1;
    globalThis.speechSynthesis.cancel();
    speaking = false;
    speechPending = false;
    if (emitState) emit('Voice ready');
    return wasSpeaking;
  }

  function stopListening({ discard = false } = {}) {
    conversationMode = false;
    clearResumeTimer();
    if (!recognition) return false;
    discardTranscript = discard;
    recognition.stop();
    return true;
  }

  function beginListening() {
    if (!Recognition) throw new Error('Speech recognition is unavailable on this browser');
    if (listening) return false;

    if (speaking) stopSpeaking({ emitState: false });

    let finalTranscript = '';
    discardTranscript = false;
    recognition = new Recognition();
    recognition.lang = lang;
    recognition.continuous = false;
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;

    recognition.onstart = () => {
      listening = true;
      emit('Listening…');
    };

    recognition.onresult = (event) => {
      let interim = '';
      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const result = event.results[index];
        const transcript = String(result?.[0]?.transcript || '');
        if (result.isFinal) finalTranscript += transcript;
        else interim += transcript;
      }
      const preview = (interim || finalTranscript).trim();
      emit(preview ? `Hearing: ${preview}` : 'Listening…');
    };

    recognition.onerror = (event) => {
      listening = false;
      const code = String(event?.error || 'speech_error');
      const friendly = code === 'not-allowed'
        ? 'Microphone/speech permission denied'
        : code === 'no-speech'
          ? 'No speech heard'
          : `Speech error: ${code}`;
      if (['not-allowed', 'service-not-allowed', 'audio-capture'].includes(code)) { conversationMode = false; clearResumeTimer(); }
      emit(friendly);
    };

    recognition.onend = () => {
      const transcript = finalTranscript.trim();
      const discarded = discardTranscript;
      const shouldResume = conversationMode && !discarded;
      listening = false;
      recognition = null;
      discardTranscript = false;
      emit(transcript && !discarded ? 'Sending voice message…' : 'Voice ready');
      if (transcript && !discarded) {
        Promise.resolve(onTranscript?.(transcript)).then(() => { if (shouldResume && !speechPending && !speaking) scheduleResume(); }).catch(() => { conversationMode = false; emit('Voice send failed'); });
      } else if (shouldResume) scheduleResume(350);
    };

    recognition.start();
    return true;
  }

  function startListening() {
    conversationMode = true;
    clearResumeTimer();
    return beginListening();
  }

  function toggleListening() {
    if (listening) return stopListening();
    if (conversationMode && !speaking && !speechPending) { conversationMode = false; clearResumeTimer(); emit('Voice ready'); return true; }
    return startListening();
  }

  function setSpeakReplies(value) {
    speakReplies = Boolean(value);
    if (!speakReplies && canSpeak) stopSpeaking({ emitState: false });
    emit(speakReplies ? 'Voice replies on' : 'Voice replies off');
    if (!speakReplies && conversationMode) scheduleResume();
    return speakReplies;
  }

  function speak(text) {
    const content = String(text || '').trim();
    if (!canSpeak || !speakReplies || !content) return false;

    clearResumeTimer();
    const generation = ++speechGeneration;
    globalThis.speechSynthesis.cancel();
    speaking = false;
    speechPending = true;
    const utterance = new globalThis.SpeechSynthesisUtterance(content);
    utterance.lang = lang;
    utterance.rate = 1;
    utterance.pitch = 1;
    utterance.onstart = () => {
      if (generation !== speechGeneration) return;
      speechPending = false;
      speaking = true;
      emit('Speaking…');
    };
    utterance.onend = () => {
      if (generation !== speechGeneration) return;
      speechPending = false;
      speaking = false;
      emit('Voice ready');
      scheduleResume();
    };
    utterance.onerror = () => {
      if (generation !== speechGeneration) return;
      speechPending = false;
      speaking = false;
      emit('Voice playback failed');
      scheduleResume(250);
    };
    globalThis.speechSynthesis.speak(utterance);
    return true;
  }

  return Object.freeze({
    capabilities,
    toggleListening,
    stopListening,
    setSpeakReplies,
    speak,
    stopSpeaking,
    isListening: () => listening,
    isSpeaking: () => speaking,
    speakRepliesEnabled: () => speakReplies
  });
}
