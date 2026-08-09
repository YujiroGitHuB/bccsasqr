// 
// PROXY URL — point this to your PHP file
// API key is hidden in PHP, no longer
// visible in browser DevTools!
// 
const GEMINI_PROXY_URL = '../api/gemini-proxy.php'; // Change path if needed
// 

const qrCodeContext = `
 About BCC SAS QR Code Generator System:
 - A comprehensive QR code generation system for student attendance
 - Features: Generate student QR codes.
 - Capabilities: Student data management
 - Security: Secure QR encoding, unique identifiers per student
 - Integration: Works with BCC Student Attendance System
 - Purpose: Streamline attendance tracking and student identification
 - Benefits: Fast scanning, accurate data, reduced manual errors
 - Support: Real-time generation, bulk operations, easy-to-use interface
 - Developed by: Mr. Charles Nixon Cayading
 `;

const quickResponses = {
    'generate': `To generate a QR code:<br><br>
 Step 1. Enter your student number.<br>
 Step 2. Click the "Generate QR Code" button.<br>
 Step 3. Your QR code will appear instantly.<br>
 Step 4. Download or print as needed.<br><br>
 It's that simple! `,
    'download': `Yes! You can easily download QR codes:<br><br>
 Click the download button after generation.<br>
 All formats are high-quality and scannable!`,
    'scanning': `To record attendance using QR code:<br><br>
 Step 1. The instructor opens the QR scanner.<br>
 Step 2. Uses the official attendance app.<br>
 Step 3. Scans the student's QR code one by one.<br>
 Step 4. Student data appears instantly.<br>
 Step 5. Attendance is recorded automatically.<br><br>
 Controlled, accurate, and secure attendance!`,
    'uses': `QR codes in this system are used for:<br><br>
 Student attendance tracking.<br>
 Quick student identification.<br>
 Secure access control.<br>
 Data collection and reporting.<br>
 Efficient and modern attendance solution!`,
    'develop': `This System was Developed by:<br><br>
 Mr. Charles Nixon Cayading!`,
    'about': `${qrCodeContext.replace(/\n/g, '<br>')}`
};

const chatToggleBtn = document.getElementById('chatToggleBtn');
const chatWidget = document.getElementById('chatWidget');
const closeChatBtn = document.getElementById('closeChatBtn');
const notificationBadge = document.querySelector('.notification-badge');
const sendBtn = document.getElementById('sendBtn');

// QUOTA TRACKER 
const DAILY_LIMIT = 1000; // Free tier daily limit for gemini-2.5-flash-lite

function getQuotaData() {
    const today = new Date().toISOString().split('T')[0]; // Format: YYYY-MM-DD
    const saved = JSON.parse(localStorage.getItem('gemini_quota') || '{}');

    // Reset if it's a new day
    if (saved.date !== today) {
        const fresh = { date: today, used: 0 };
        localStorage.setItem('gemini_quota', JSON.stringify(fresh));
        localStorage.removeItem('last_warn'); // Also reset the warning tracker
        return fresh;
    }
    return saved;
}

function incrementQuota() {
    const data = getQuotaData();
    data.used += 1;
    localStorage.setItem('gemini_quota', JSON.stringify(data));
    updateQuotaDisplay();
}

function getRemainingQuota() {
    const data = getQuotaData();
    return DAILY_LIMIT - data.used;
}

function updateQuotaDisplay() {
    const remaining = getRemainingQuota();
    const badge = document.getElementById('quotaBadge');
    if (!badge) return;

    // Update badge text
    if (remaining <= 0) {
        badge.textContent = ' Limit Reached';
        badge.style.background = '#7f1d1d';
        badge.title = 'Daily quota exhausted! Resets at midnight Pacific Time.';
    } else if (remaining <= 10) {
        badge.textContent = ' ' + remaining + ' left';
        badge.style.background = '#ef4444';
        badge.title = 'CRITICAL! Only ' + remaining + ' free requests remaining today.';
    } else if (remaining <= 50) {
        badge.textContent = ' ' + remaining + ' left';
        badge.style.background = '#ef4444';
        badge.title = 'Almost out! ' + remaining + ' free requests remaining today.';
    } else if (remaining <= 200) {
        badge.textContent = '[!] ' + remaining + ' left';
        badge.style.background = '#f97316';
        badge.title = 'Warning! ' + remaining + ' free requests remaining today.';
    } else {
        badge.textContent = remaining + ' left';
        badge.style.background = '#22c55e';
        badge.title = remaining + ' free requests remaining today. Resets at midnight.';
    }

    // Show warning popup when quota is low
    // Range-based checks so warnings are never missed even if count jumps
    if (remaining === 0) {
        showQuotaWarning(0);
    } else if (remaining <= 10 && remaining % 1 === 0) {
        // Warn on every request when <= 10 remaining
        const lastWarn = parseInt(localStorage.getItem('last_warn') || '999');
        if (remaining < lastWarn) {
            showQuotaWarning(remaining);
            localStorage.setItem('last_warn', remaining);
        }
    } else if (remaining <= 50) {
        const lastWarn = parseInt(localStorage.getItem('last_warn') || '999');
        if (lastWarn > 50) {
            showQuotaWarning(remaining);
            localStorage.setItem('last_warn', remaining);
        }
    } else if (remaining <= 100) {
        const lastWarn = parseInt(localStorage.getItem('last_warn') || '999');
        if (lastWarn > 100) {
            showQuotaWarning(remaining);
            localStorage.setItem('last_warn', remaining);
        }
    } else if (remaining <= 200) {
        const lastWarn = parseInt(localStorage.getItem('last_warn') || '999');
        if (lastWarn > 200) {
            showQuotaWarning(remaining);
            localStorage.setItem('last_warn', remaining);
        }
    }
}

function showQuotaWarning(remaining) {
    let msg, cleanText;

    if (remaining === 0) {
        msg = ' <b>Quota exhausted!</b> The AI has used all 1,000 free requests for today. Resets tomorrow at midnight! Quick responses (Generate QR, Download, Scan) still work. ';
        cleanText = 'Quota exhausted! The AI has no more free requests for today. Resets at midnight.';
    } else if (remaining <= 10) {
        msg = ' <b>CRITICAL:</b> Only <b>' + remaining + ' requests</b> left today! Save them for important questions.';
        cleanText = 'Critical! Only ' + remaining + ' free requests remaining today.';
    } else if (remaining <= 50) {
        msg = ' <b>Almost out!</b> Only <b>' + remaining + ' requests</b> left for today. Resets at midnight!';
        cleanText = 'Warning! Only ' + remaining + ' free requests remaining today.';
    } else if (remaining <= 100) {
        msg = '<b>Low quota:</b> <b>' + remaining + ' requests</b> remaining for today. Resets at midnight!';
        cleanText = 'Low quota. ' + remaining + ' free requests remaining today.';
    } else {
        msg = '<b>Heads up!</b> <b>' + remaining + ' requests</b> remaining for today. Resets at midnight!';
        cleanText = remaining + ' free requests remaining today.';
    }

    addMessage(msg, false);
    TTSManager.speak(cleanText);
}

// Inject quota badge into the DOM on page load
function injectQuotaBadge() {
    // Find the chat header or toggle button to place the badge
    const existingBadge = document.getElementById('quotaBadge');
    if (existingBadge) return;

    const badge = document.createElement('div');
    badge.id = 'quotaBadge';
    badge.style.cssText = `
 position: fixed;
 bottom: 80px;
 right: 20px;
 background: #22c55e;
 color: white;
 font-size: 11px;
 font-weight: 600;
 padding: 4px 10px;
 border-radius: 20px;
 box-shadow: 0 2px 8px rgba(0,0,0,0.2);
 z-index: 9999;
 cursor: default;
 font-family: monospace;
 letter-spacing: 0.5px;
 transition: background 0.3s;
 `;
    document.body.appendChild(badge);
    updateQuotaDisplay();
}

// CONVERSATION HISTORY 
let geminiHistory = [];

// Load voices when they become available
if ('speechSynthesis' in window) {
    speechSynthesis.addEventListener('voiceschanged', () => {
        const voices = speechSynthesis.getVoices();
        console.log('Available voices:', voices.map(v => v.name + ' (' + v.lang + ')'));
    });
}

// Init quota badge on page load
document.addEventListener('DOMContentLoaded', () => {
    injectQuotaBadge();
});

// Speak when chat opens
chatToggleBtn.addEventListener('click', () => {
    chatWidget.classList.add('active');
    if (notificationBadge) {
        notificationBadge.style.display = 'none';
    }
    TTSManager.speak("Hi I'm Lexon, your chatbot assistant. I'm here to help you with QR code generation and answer any questions you have about this system. What would you like to know?");
});

closeChatBtn.addEventListener('click', () => {
    chatWidget.classList.remove('active');
    window.speechSynthesis.cancel();
});

function addMessage(text, isUser) {
    const messagesContainer = document.getElementById('chatMessages');
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${isUser ? 'user' : 'bot'}`;

    messageDiv.innerHTML = `
<div class="avatar">${isUser ? '👤' : '🤖'}</div>
 <div class="message-content">${text}</div>
 `;

    messagesContainer.appendChild(messageDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
    return messageDiv;
}

function showTypingIndicator() {
    const messagesContainer = document.getElementById('chatMessages');
    const typingDiv = document.createElement('div');
    typingDiv.className = 'message bot';
    typingDiv.id = 'typingIndicator';

    typingDiv.innerHTML = `
 <div class="avatar"></div>
 <div class="typing-indicator">
 <div class="typing-dot"></div>
 <div class="typing-dot"></div>
 <div class="typing-dot"></div>
 </div>
 `;

    messagesContainer.appendChild(typingDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

function removeTypingIndicator() {
    const typingIndicator = document.getElementById('typingIndicator');
    if (typingIndicator) {
        typingIndicator.remove();
    }
}

// GEMINI API CALL 
async function callGeminiAPI(userMessage) {
    // System context included in the conversation history
    const systemInstruction = `You are Lexon, a friendly and helpful chatbot assistant for the BCC SAS QR Code Generator System. 
 Always respond in a helpful, friendly, and concise manner. 
 Here is the context about the system you support:
 ${qrCodeContext}

 Keep responses short and easy to understand. If asked something unrelated to the system, still be helpful but remind the user you specialize in the QR Code Generator System.
 
 IMPORTANT: Always respond in English only, regardless of the language used by the user. Even if the user writes in Tagalog, Filipino, or any other language, your reply must always be in English.`;
    // Add user message to history
    geminiHistory.push({
        role: 'user',
        parts: [{ text: userMessage }]
    });

    const response = await fetch(
        GEMINI_PROXY_URL, // Calls the PHP proxy — API key is safely hidden on the server!
        {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                system_instruction: {
                    parts: [{ text: systemInstruction }]
                },
                contents: geminiHistory,
                generationConfig: {
                    temperature: 0.7,
                    maxOutputTokens: 300
                }
            })
        }
    );

    const data = await response.json();

    if (!response.ok) {
        const errMsg = data?.error?.message || 'Gemini API error';
        if (response.status === 429 || errMsg.toLowerCase().includes('quota') || errMsg.toLowerCase().includes('rate')) {
            throw new Error('QUOTA_EXCEEDED');
        }
        throw new Error(errMsg);
    }

    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text || 'Sorry, I could not generate a response.';

    // Add AI reply to history to maintain multi-turn conversation
    geminiHistory.push({
        role: 'model',
        parts: [{ text: reply }]
    });

    incrementQuota(); // Track API usage
    return reply;
}

// MAIN AI RESPONSE FUNCTION 
async function getAIResponse(userMessage) {
    const message = userMessage.toLowerCase();

    // Quick responses for common keywords (no API call needed, instant!)
    if (message.includes('generate') || message.includes('create') || message.includes('make')) return quickResponses.generate;
    if (message.includes('download') || message.includes('save') || message.includes('export')) return quickResponses.download;
    if (message.includes('scan') || message.includes('read')) return quickResponses.scanning;
    if (message.includes('use') || message.includes('purpose') || message.includes('why')) return quickResponses.uses;
    if (message.includes('who') || message.includes('developed') || message.includes('developer')) return quickResponses.develop;
    if (message.includes('about') || message.includes('info') || message.includes('system') || message.includes('context')) return quickResponses.about;

    // If no quick response matched, use Gemini AI
    try {
        const geminiReply = await callGeminiAPI(userMessage);
        return geminiReply;
    } catch (error) {
        console.error('Gemini error:', error.message);

        // Quota/rate limit exceeded — force update the badge and counter
        if (error.message === 'QUOTA_EXCEEDED') {
            const today = new Date().toISOString().split('T')[0];
            localStorage.setItem('gemini_quota', JSON.stringify({ date: today, used: 1000 }));
            localStorage.setItem('last_warn', '0');
            updateQuotaDisplay();
            showQuotaWarning(0);
            return ' Sorry, the AI has reached its daily free limit. Please try again tomorrow or contact the system administrator. In the meantime, try asking: <b>Generate QR, Download, Scanning, About System</b> — these work without AI! ';
        }

        // Fallback responses if Gemini API is unavailable
        if (message.includes('hello') || message.includes('hi') || message.includes('hey')) {
            return "Hello! I'm Lexon, here to help you with the QR Code Generator System. Feel free to ask about generating QR codes or how to use the system!";
        }
        if (message.includes('how') && message.includes('work')) {
            return 'The QR Code Generator creates unique QR codes for each student. Simply select a student, click generate, and you\'ll have a scannable QR code ready for attendance tracking!';
        }
        if (message.includes('student') || message.includes('attendance')) {
            return 'This system generates QR codes specifically for student attendance tracking. Each student gets a unique QR code that can be scanned for quick and accurate attendance recording!';
        }
        if (message.includes('secure') || message.includes('safe') || message.includes('security')) {
            return 'Security is built-in! Each QR code contains encrypted student information and unique identifiers, ensuring data integrity and preventing unauthorized access.';
        }
        if (message.includes('thank')) {
            return "You're welcome! Feel free to ask if you need any more help with the QR Code Generator System.";
        }

        return "That's a great question! Try asking: Generate QR, Download, Scanning, QR uses, How it Works, Student Attendance, Security, or About System. What would you like to know?";
    }
}

async function sendMessage() {
    const input = document.getElementById('chatInput');
    const message = input.value.trim();

    if (message === '') return;

    input.disabled = true;
    sendBtn.disabled = true;

    addMessage(message, true);
    input.value = '';

    showTypingIndicator();

    try {
        const response = await getAIResponse(message);
        removeTypingIndicator();
        addMessage(response, false);

        const cleanText = response.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
        TTSManager.speak(cleanText);
    } catch (error) {
        removeTypingIndicator();
        const errorMsg = "I'm here to help! Ask me about generating QR codes, customization, downloading, or scanning.";
        addMessage(errorMsg, false);
        TTSManager.speak(errorMsg);
    } finally {
        input.disabled = false;
        sendBtn.disabled = false;
        input.focus();
    }
}

async function sendQuickReply(message) {
    addMessage(message, true);
    showTypingIndicator();

    try {
        const response = await getAIResponse(message);
        removeTypingIndicator();
        addMessage(response, false);

        const cleanText = response.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
        TTSManager.speak(cleanText);
    } catch (error) {
        removeTypingIndicator();
        const errorMsg = 'Let me help you with that!';
        addMessage(errorMsg, false);
        TTSManager.speak(errorMsg);
    }
}

function handleKeyPress(event) {
    if (event.key === 'Enter' && !sendBtn.disabled) {
        sendMessage();
    }
}