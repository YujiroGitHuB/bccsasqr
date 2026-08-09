function confirmLogout() {
    // Jarvis-style text-to-speech function
    function speakJarvis(text) {
        if ('speechSynthesis' in window) {
            window.speechSynthesis.cancel();

            const voices = window.speechSynthesis.getVoices();
            const utterance = new SpeechSynthesisUtterance(text);

            // Try to find British English voice
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

    // Load voices
    if ('speechSynthesis' in window) {
        window.speechSynthesis.getVoices();
    }

    // Jarvis-style logout confirmation
    speakJarvis('Are you certain you wish to terminate your session?');
    Swal.fire({
        title: 'Log out?',
        text: 'You’re about to end your session.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Logout',
        cancelButtonText: 'Stay',
        background: '#121212', // deep dark
        color: '#e0e0e0', // light gray text
        iconColor: '#00e5ff', // cyan accent for icon
        confirmButtonColor: '#00bfa6',
        cancelButtonColor: '#444',
        reverseButtons: true,
        customClass: {
            popup: 'modern-dark-popup',
            title: 'modern-dark-title',
            htmlContainer: 'modern-dark-text',
            confirmButton: 'modern-dark-confirm',
            cancelButton: 'modern-dark-cancel'
        }
    }).then((result) => {
        if (result.isConfirmed) {
            Swal.fire({
                background: '#121212',
                color: '#e0e0e0',
                icon: 'success',
                title: 'Logging out...',
                showConfirmButton: false,
                timer: 1000,
                didOpen: () => {
                    speakJarvis('Logging out now. Until next time.');
                },
                didClose: () => {
                    window.location.href = '../includes/logout.php';
                }
            });
        } else if (result.isDismissed) {
            speakJarvis('Very well. Session maintained.');
        }
    });
}
