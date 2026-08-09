// Text-to-Speech Utility Module
// Usage: import this file and use TTSManager.speak("Your message here")

const TTSManager = {
    // Speak a message with optional callback
    speak(text, onEnd = null) {
        if (!window.speechSynthesis) {
            console.warn('[TTS] Speech synthesis not supported');
            return;
        }

        // Cancel any ongoing speech
        this.cancel();

        const utterance = new SpeechSynthesisUtterance(text);

        // Set voice when ready
        const setVoice = () => {
            const voices = window.speechSynthesis.getVoices();
            
            // Try to find a male English voice
            const maleVoice = voices.find(voice =>
                voice.lang.startsWith('en') && (
                    voice.name.includes('Male') ||
                    voice.name.includes('David') ||
                    voice.name.includes('Mark') ||
                    voice.name.includes('Daniel') ||
                    voice.name.includes('James') ||
                    (voice.name.includes('Alex') && !voice.name.includes('Alexa'))
                )
            );

            // Fallback to any English voice
            const voice = maleVoice || voices.find(v => v.lang.startsWith('en'));
            if (voice) utterance.voice = voice;

            // Voice settings
            utterance.rate = 1;
            utterance.pitch = 1;
            utterance.volume = 1;

            // Add callback if provided
            if (onEnd) utterance.onend = onEnd;

            window.speechSynthesis.speak(utterance);
        };

        // Check if voices are already loaded
        if (window.speechSynthesis.getVoices().length > 0) {
            setVoice();
        } else {
            window.speechSynthesis.addEventListener('voiceschanged', setVoice, { once: true });
        }
    },

    // Cancel/stop any ongoing speech
    cancel() {
        if (window.speechSynthesis) {
            window.speechSynthesis.cancel();
        }
    },

    // Check if currently speaking
    isSpeaking() {
        return window.speechSynthesis && window.speechSynthesis.speaking;
    },

    // Pause current speech
    pause() {
        if (window.speechSynthesis) {
            window.speechSynthesis.pause();
        }
    },

    // Resume paused speech
    resume() {
        if (window.speechSynthesis) {
            window.speechSynthesis.resume();
        }
    }
};

// Auto-cancel speech on page unload/refresh
window.addEventListener('beforeunload', () => TTSManager.cancel());
window.addEventListener('pagehide', () => TTSManager.cancel());

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = TTSManager;
}