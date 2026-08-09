<?php if (isset($_SESSION['alert'])): ?>
    <script>
        // Jarvis-style text-to-speech function
        function speakJarvis(text) {
            if ('speechSynthesis' in window) {
                // Cancel any ongoing speech
                window.speechSynthesis.cancel();

                // Get available voices
                const voices = window.speechSynthesis.getVoices();

                const utterance = new SpeechSynthesisUtterance(text);

                const britishVoice = voices.find(voice =>
                    voice.name.includes('Male') ||
                    voice.name.includes('David') ||
                    voice.name.includes('Mark') ||
                    voice.name.includes('Daniel') ||
                    voice.name.includes('James') ||
                    voice.name.includes('Alex') && !voice.name.includes('Alexa')
                );

                if (britishVoice) {
                    utterance.voice = britishVoice;
                }

                utterance.lang = 'en-US'; 
                utterance.rate = 1; 
                utterance.pitch = 1; 
                utterance.volume = 1;

                window.speechSynthesis.speak(utterance);
            }
        }

        // Load voices (some browsers need this)
        if ('speechSynthesis' in window) {
            window.speechSynthesis.getVoices();
            window.speechSynthesis.onvoiceschanged = () => {
                window.speechSynthesis.getVoices();
            };
        }

        // Prepare Jarvis-style speech text
        const alertIcon = '<?= $_SESSION['alert']['icon'] ?>';
        const alertTitle = '<?= $_SESSION['alert']['title'] ?>';
        const alertText = '<?= $_SESSION['alert']['text'] ?>';

        let jarvisSpeech = '';

        // Customize speech based on alert type (Jarvis-style)
        switch (alertIcon) {
            case 'success':
                if (alertTitle.toLowerCase().includes('login')) {
                    jarvisSpeech = 'Welcome back. System access granted. ' + alertText;
                } else {
                    jarvisSpeech = 'Operation successful. ' + alertTitle + '. ' + alertText;
                }
                break;
            case 'error':
                jarvisSpeech = 'I apologize. ' + alertTitle + '. ' + alertText;
                break;
            case 'warning':
                jarvisSpeech = 'Warning. ' + alertTitle + '. ' + alertText;
                break;
            case 'info':
                jarvisSpeech = 'Information. ' + alertTitle + '. ' + alertText;
                break;
            default:
                jarvisSpeech = alertTitle + '. ' + alertText;
        }

        // Speak in Jarvis style
        speakJarvis(jarvisSpeech);

        Swal.fire({
            icon: alertIcon,
            title: alertTitle,
            text: alertText,
            position: '<?= $_SESSION['alert']['position'] ?>',
            showConfirmButton: false,
            timer: 3500,
            background: '#1e293b',
            color: '#fff'
        }).then(() => {
            <?php if (!empty($_SESSION['alert']['redirect'])): ?>
                window.location.href = '<?= $_SESSION['alert']['redirect'] ?>';
            <?php endif; ?>
        });
    </script>
<?php unset($_SESSION['alert']);
endif; ?>