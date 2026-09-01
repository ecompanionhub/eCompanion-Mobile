export function createVoiceAdapter({ language, onTranscript, onState } = {}) {
  const Recognition = globalThis.SpeechRecognition || globalThis.webkitSpeechRecognition || null;
  const canSpeak = Boolean(globalThis.speechSynthesis && globalThis.SpeechSynthesisUtterance);
  const lang = String(language || globalThis.navigator?.language || 'en-US');

  let recognition = null;
  let listening = false;
  let speakReplies = true;

  function emit(text) {
    onState?.({ listening, speakReplies, text });
  }

  function capabilities() {
    return Object.freeze({
      speech_recognition: Boolean(Recognition),
      speech_synthesis: canSpeak
    });
  }

  function stopListening() {
    if (!recognition || !listening) return false;
    recognition.stop();
    return true;
  }

  function startListening() {
    if (!Recognition) throw new Error('Speech recognition is unavailable on this browser');
    if (listening) return false;

    let finalTranscript = '';
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
      emit(friendly);
    };

    recognition.onend = () => {
      const transcript = finalTranscript.trim();
      listening = false;
      recognition = null;
      emit(transcript ? 'Sending voice message…' : 'Voice ready');
      if (transcript) Promise.resolve(onTranscript?.(transcript)).catch(() => emit('Voice send failed'));
    };

    recognition.start();
    return true;
  }

  function toggleListening() {
    return listening ? stopListening() : startListening();
  }

  function setSpeakReplies(value) {
    speakReplies = Boolean(value);
    if (!speakReplies && canSpeak) globalThis.speechSynthesis.cancel();
    emit(speakReplies ? 'Voice replies on' : 'Voice replies off');
    return speakReplies;
  }

  function speak(text) {
    const content = String(text || '').trim();
    if (!canSpeak || !speakReplies || !content) return false;

    globalThis.speechSynthesis.cancel();
    const utterance = new globalThis.SpeechSynthesisUtterance(content);
    utterance.lang = lang;
    utterance.rate = 1;
    utterance.pitch = 1;
    utterance.onstart = () => emit('Speaking…');
    utterance.onend = () => emit('Voice ready');
    utterance.onerror = () => emit('Voice playback failed');
    globalThis.speechSynthesis.speak(utterance);
    return true;
  }

  function stopSpeaking() {
    if (!canSpeak) return false;
    globalThis.speechSynthesis.cancel();
    emit('Voice ready');
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
    speakRepliesEnabled: () => speakReplies
  });
}
