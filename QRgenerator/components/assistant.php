    <!-- Chat Toggle Button -->
    <button class="chat-toggle-btn" id="chatToggleBtn">
        <img width="50" height="50" style="border-radius: 50px;"
            src="https://cdn-icons-gif.flaticon.com/15579/15579168.gif" alt="">
        <span class="notification-badge">1</span>
    </button>

    <!-- Chat Widget -->
    <div class="chat-widget-container" id="chatWidget">
        <div class="chat-header">
            <div class="chat-header-content">
                <h3><span class="status-dot"></span>ChatBot Assistant: Lexon</h3>
                <p><i>Your Smart QR Generator Helper</i></p>
            </div>
            <button class="close-chat-btn" id="closeChatBtn">×</button>
        </div>

        <div class="chat-messages" id="chatMessages">
            <div class="message bot">
                <div class="avatar">🤖</div>
                <div class="message-content">
                    Hi! I'm Lexon, your ChatBot assistant. I'm here to help you with QR code generation and answer any questions you have about this system. What would you like to know?
                </div>
            </div>
        </div>

       

        <div class="chat-input-container">
            <div class="chat-input-wrapper">
                <input type="text" class="chat-input" id="chatInput" placeholder="Type your message..."
                    onkeypress="handleKeyPress(event)">
                <button class="send-btn" id="sendBtn" onclick="sendMessage()">➤</button>
            </div>
        </div>
    </div>