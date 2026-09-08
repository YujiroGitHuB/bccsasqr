// Text-to-Speech Utility Module
// Usage: import this file and use TTSManager.speak("Your message here")

const TTSManager = {
    /**
     * Turn a record's name into something the voice will pronounce as a
     * name. Names come out of the school's export in the form
     * "DELA CRUZ, JUAN P." — and every speech engine reads an all-caps
     * word as an initialism, so that gets spelled out letter by letter.
     * Title case fixes the spelling; the rest just makes it sound like a
     * person being called.
     */
    nameForSpeech(name) {
        let s = String(name ?? '').trim().replace(/\s+/g, ' ');
        if (!s) return '';

        // "LAST, FIRST MIDDLE" → "FIRST MIDDLE LAST"
        const comma = s.indexOf(',');
        if (comma > -1) {
            s = s.slice(comma + 1).trim() + ' ' + s.slice(0, comma).trim();
        }

        // A suffix is spelled out ("J-R", "I-I-I") by every engine, so it
        // is said as the word instead — and it belongs after the
        // surname, not stranded in the middle where the swap above left
        // it.
        const SUFFIX = {
            jr: 'Junior', sr: 'Senior',
            ii: 'the Second', iii: 'the Third', iv: 'the Fourth'
        };

        const words   = s.split(' ');
        const spoken  = [];
        let   suffix  = '';

        for (const w of words) {
            const bare = w.replace(/\.$/, '').toLowerCase();
            if (SUFFIX[bare]) { suffix = SUFFIX[bare]; continue; }
            // A lone initial ("P.") is read as a letter no matter what,
            // and adds nothing when the name is spoken aloud.
            if (/^[A-Za-z]\.?$/.test(w)) continue;
            // Title case each part, so "DELA CRUZ-SANTOS" survives.
            spoken.push(w.toLowerCase().replace(/(^|[-'’])([a-zà-ÿ])/g,
                (_, sep, c) => sep + c.toUpperCase()));
        }

        if (suffix) spoken.push(suffix);
        return spoken.join(' ').trim();
    },

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

            // Chrome drops the utterance when speak() lands in the same
            // task as the cancel() above — the queue is still tearing
            // down. One tick of breathing room is enough, and it is why
            // back-to-back scans used to fall silent.
            setTimeout(() => window.speechSynthesis.speak(utterance), 60);
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