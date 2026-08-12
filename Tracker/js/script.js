let typingTimer;
const typingDelay = 1000;
const input = document.getElementById('studentNoInput');
const searchWrapper = document.querySelector('.search-wrapper');
const resultsContainer = document.getElementById('resultsContainer');
const messageContainer = document.getElementById('messageContainer');
const placeholder = document.getElementById('trkPlaceholder');

// A class on the wrapper, not `style.display` on each span — CSS
// cannot win back an inline style, which would leave "Type to search"
// impossible to hide on a narrow phone.
function setChecking(isChecking) {
    searchWrapper.classList.toggle('is-checking', isChecking);
}

// The waiting state is only for before the first search; once you can
// see results it has nothing left to say.
function setPlaceholder(visible) {
    if (placeholder) {
        placeholder.classList.toggle('hidden', !visible);
    }
}

function showResults(html) {
    resultsContainer.innerHTML = html;
    resultsContainer.classList.remove('hidden');
    setPlaceholder(false);
}

function showMessage(type, text, icon) {
    const messageClass = `message-${type}`;
    messageContainer.innerHTML = `
                <div class="message-box ${messageClass}">
                    ${icon}
                    <span>${text}</span>
                </div>
            `;
}

function clearMessage() {
    messageContainer.innerHTML = '';
}

input.addEventListener('input', function () {
    clearTimeout(typingTimer);

    const value = this.value.trim();

    if (value.length === 0) {
        setChecking(false);
        resultsContainer.classList.add('hidden');
        resultsContainer.innerHTML = '';
        setPlaceholder(true);
        clearMessage();
        return;
    }

    setChecking(true);
    clearMessage();

    typingTimer = setTimeout(() => {
        searchAttendance(value);
    }, typingDelay);
});

input.addEventListener('keydown', function () {
    clearTimeout(typingTimer);
});

async function searchAttendance(studentNo) {
    console.log('=== SEARCH STARTED ===');
    console.log('Student No:', studentNo);

    // Show checking message
    showMessage('checking', 'Searching Student Attendance Record...', `
                <svg class="spinner" viewBox="0 0 24 24">
                    <circle class="spinner-circle" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" fill="none"></circle>
                </svg>
            `);

    // TTS for searching
    if (typeof TTSManager !== 'undefined') {
        console.log('TTS Speaking...');
        TTSManager.speak('Searching Student Attendance record');
    }

    console.log('Waiting 3 seconds...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    console.log('Wait complete!');

    try {
        console.log('Creating FormData...');
        const formData = new FormData();
        formData.append('student_no', studentNo);
        console.log('FormData created');

        console.log('Sending fetch request...');
        const response = await fetch('', {
            method: 'POST',
            body: formData
        });
        console.log('Fetch response received:', response);
        console.log('Response OK?', response.ok);
        console.log('Response status:', response.status);

        console.log('Getting response text...');
        const html = await response.text();
        console.log('Response received! Length:', html.length);
        console.log('First 500 characters:', html.substring(0, 500));

        console.log('Parsing HTML...');
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        console.log('HTML parsed');

        console.log('Looking for .results-container...');
        const results = doc.querySelector('.results-container');
        console.log('Results found?', results !== null);

        if (results) {
            console.log('Status attribute:', results.getAttribute('data-status'));
            console.log('Results innerHTML preview:', results.innerHTML.substring(0, 200));
        } else {
            console.log('NO RESULTS CONTAINER!');
            console.log('All classes in parsed doc:', Array.from(doc.querySelectorAll('[class]')).map(el => el.className));
        }

        console.log('Hiding status indicators...');
        setChecking(false);
        console.log('Status indicators updated');

        if (results) {
            const status = results.getAttribute('data-status');
            console.log('Processing status:', status);

            if (status === 'success') {
                console.log('SUCCESS PATH');
                const successMsg = 'Attendance Records loaded successfully!';
                showMessage('success', successMsg, `
                    <svg class="checkmark-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
                    </svg>
                `);

                if (typeof TTSManager !== 'undefined') {
                    TTSManager.speak(successMsg);
                }

                showResults(results.innerHTML);
                console.log('Results displayed');

            } else if (status === 'no-attendance') {
                console.log('NO ATTENDANCE PATH');
                const noAttendanceMsg = 'Student found but no attendance records yet.';
                showMessage('info', noAttendanceMsg, `
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                `);

                if (typeof TTSManager !== 'undefined') {
                    TTSManager.speak(noAttendanceMsg);
                }

                showResults(results.innerHTML);
                console.log('No attendance message displayed');

            } else if (status === 'not-found') {
                console.log('NOT FOUND PATH');
                const errorMsg = 'Student not found. Please check your student number and try again.';
                showMessage('error', errorMsg, `
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                `);

                if (typeof TTSManager !== 'undefined') {
                    TTSManager.speak(errorMsg);
                }

                showResults(`
                    <div class="no-results">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                        <h3>Student not found</h3>
                        <p>No record matches that student number. Check for a missing dash or a typo, then try again.</p>
                    </div>
                `);
                console.log('Not found message displayed');
            } else {
                console.log('UNKNOWN STATUS:', status);
            }
        } else {
            console.log('ELSE PATH - NO RESULTS');
            const errorMsg = 'Student not found. Please check your student number and try again.';
            showMessage('error', errorMsg, `
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
            `);

            if (typeof TTSManager !== 'undefined') {
                TTSManager.speak(errorMsg);
            }

            showResults(`
                <div class="no-results">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    <h3>Student not found</h3>
                    <p>No record matches that student number. Check for a missing dash or a typo, then try again.</p>
                </div>
            `);
            console.log('Fallback error displayed');
        }

        console.log('=== SEARCH COMPLETED ===');

    } catch (error) {
        console.error('=== CATCH BLOCK ===');
        console.error('Search error:', error);
        console.error('Error message:', error.message);
        console.error('Error stack:', error.stack);

        setChecking(false);

        const errorMsg = 'Database connection error. Please try again.';
        showMessage('error', errorMsg, `
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                `);

        if (typeof TTSManager !== 'undefined') {
            TTSManager.speak(errorMsg);
        }

        showResults(`
                    <div class="no-results">
                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                        <h3>Something went wrong</h3>
                        <p>Please try again later.</p>
                    </div>
                `);
        console.log('Error handler executed');
    }
}