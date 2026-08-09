<!DOCTYPE html>
<html>
<head>
    <title>Error</title>
    <link rel="shortcut icon" href="https://cdn-icons-png.flaticon.com/128/15525/15525396.png" type="image/x-icon">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0f0c29 0%, #302b63 50%, #24243e 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            overflow: hidden;
            position: relative;
        }
        /* Animated background particles */
        body::before {
            content: '';
            position: absolute;
            width: 200%;
            height: 200%;
            background: radial-gradient(circle, rgba(255,255,255,0.03) 1px, transparent 1px);
            background-size: 50px 50px;
            animation: drift 20s linear infinite;
        }

        @keyframes drift {
            from { transform: translate(0, 0); }
            to { transform: translate(50px, 50px); }
        }

        /* Floating orbs */
        .orb {
            position: absolute;
            border-radius: 50%;
            filter: blur(60px);
            opacity: 0.3;
            animation: float 20s ease-in-out infinite;
        }

        .orb1 {
            width: 400px;
            height: 400px;
            background: rgba(139, 92, 246, 0.4);
            top: -200px;
            left: -200px;
            animation-delay: 0s;
        }

        .orb2 {
            width: 350px;
            height: 350px;
            background: rgba(236, 72, 153, 0.3);
            bottom: -175px;
            right: -175px;
            animation-delay: -7s;
        }

        .orb3 {
            width: 300px;
            height: 300px;
            background: rgba(59, 130, 246, 0.3);
            top: 50%;
            right: -150px;
            animation-delay: -14s;
        }

        @keyframes float {
            0%, 100% { transform: translate(0, 0) scale(1); }
            33% { transform: translate(50px, -50px) scale(1.1); }
            66% { transform: translate(-30px, 30px) scale(0.9); }
        }

        .error-box {
            background: rgba(20, 20, 35, 0.9);
            backdrop-filter: blur(20px);
            padding: 50px 40px;
            border-radius: 24px;
            width: 480px;
            text-align: center;
            box-shadow: 0 25px 70px rgba(0,0,0,0.6), 
                        0 0 0 1px rgba(139, 92, 246, 0.2),
                        inset 0 1px 0 rgba(255,255,255,0.05);
            position: relative;
            animation: slideIn 0.6s ease-out;
            transform-origin: center;
            z-index: 10;
        }

        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(-30px) scale(0.9);
            }
            to {
                opacity: 1;
                transform: translateY(0) scale(1);
            }
        }

        .icon-wrapper {
            width: 90px;
            height: 90px;
            margin: 0 auto 25px;
            background: linear-gradient(135deg, #ef4444, #dc2626);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 10px 30px rgba(239, 68, 68, 0.5),
                        0 0 0 10px rgba(239, 68, 68, 0.1),
                        inset 0 -5px 10px rgba(0,0,0,0.2);
            animation: pulse 2s ease-in-out infinite;
            position: relative;
        }

        .icon-wrapper::after {
            content: '';
            position: absolute;
            width: 100%;
            height: 100%;
            border-radius: 50%;
            border: 2px solid rgba(239, 68, 68, 0.6);
            animation: ripple 2s ease-out infinite;
        }

        @keyframes ripple {
            0% {
                transform: scale(1);
                opacity: 1;
            }
            100% {
                transform: scale(1.6);
                opacity: 0;
            }
        }

        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); }
        }

        .icon-wrapper::before {
            content: '⚠';
            font-size: 48px;
            color: white;
            animation: shake 0.5s ease-in-out;
            position: relative;
            z-index: 1;
            filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
        }

        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-5px); }
            75% { transform: translateX(5px); }
        }

        h2 {
            color: #f1f5f9;
            font-size: 32px;
            margin-bottom: 15px;
            font-weight: 700;
            animation: fadeIn 0.8s ease-out 0.2s both;
            text-shadow: 0 2px 20px rgba(139, 92, 246, 0.3);
            letter-spacing: -0.5px;
        }

        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateY(10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        p {
            color: #94a3b8;
            font-size: 16px;
            line-height: 1.7;
            margin-bottom: 12px;
            animation: fadeIn 0.8s ease-out 0.4s both;
        }

        p:last-of-type {
            animation-delay: 0.6s;
        }

        .retry-button {
            margin-top: 30px;
            padding: 15px 40px;
            background: linear-gradient(135deg, #8b5cf6, #6366f1);
            color: white;
            border: none;
            border-radius: 30px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 8px 20px rgba(139, 92, 246, 0.4),
                        0 0 0 1px rgba(139, 92, 246, 0.3),
                        inset 0 1px 0 rgba(255,255,255,0.2);
            animation: fadeIn 0.8s ease-out 0.8s both;
            position: relative;
            overflow: hidden;
        }

        .retry-button::before {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            width: 0;
            height: 0;
            border-radius: 50%;
            background: rgba(255,255,255,0.15);
            transform: translate(-50%, -50%);
            transition: width 0.6s, height 0.6s;
        }

        .retry-button:hover::before {
            width: 350px;
            height: 350px;
        }

        .retry-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 12px 30px rgba(139, 92, 246, 0.6),
                        0 0 0 1px rgba(139, 92, 246, 0.4),
                        inset 0 1px 0 rgba(255,255,255,0.2);
        }

        .retry-button:active {
            transform: translateY(-1px);
            box-shadow: 0 5px 15px rgba(139, 92, 246, 0.4);
        }

        .retry-button > * {
            position: relative;
            z-index: 1;
        }

        /* Loading spinner for retry */
        .loading {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid rgba(255,255,255,0.3);
            border-top-color: white;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin-left: 8px;
            vertical-align: middle;
            opacity: 0;
        }

        .retry-button.loading .loading {
            opacity: 1;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .contact-link {
            color: #a78bfa;
            text-decoration: none;
            font-weight: 600;
            transition: all 0.3s ease;
            position: relative;
        }

        .contact-link::after {
            content: '';
            position: absolute;
            width: 0;
            height: 2px;
            bottom: -2px;
            left: 0;
            background: linear-gradient(90deg, #8b5cf6, #6366f1);
            transition: width 0.3s ease;
        }

        .contact-link:hover {
            color: #c4b5fd;
        }

        .contact-link:hover::after {
            width: 100%;
        }

        /* Error code display */
        .error-code {
            display: inline-block;
            margin-top: 25px;
            padding: 10px 20px;
            background: rgba(139, 92, 246, 0.1);
            border: 1px solid rgba(139, 92, 246, 0.3);
            border-radius: 25px;
            color: #a78bfa;
            font-size: 13px;
            font-family: 'Courier New', monospace;
            animation: fadeIn 0.8s ease-out 1s both;
            box-shadow: 0 4px 10px rgba(139, 92, 246, 0.1);
        }

        /* Status indicator */
        .status-indicator {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            margin-top: 25px;
            color: #64748b;
            font-size: 14px;
            animation: fadeIn 0.8s ease-out 1.2s both;
        }

        .status-dot {
            width: 10px;
            height: 10px;
            background: #ef4444;
            border-radius: 50%;
            animation: blink 2s ease-in-out infinite;
            box-shadow: 0 0 10px rgba(239, 68, 68, 0.6);
        }

        @keyframes blink {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }

        /* Additional info section */
        .additional-info {
            margin-top: 30px;
            padding-top: 25px;
            border-top: 1px solid rgba(148, 163, 184, 0.15);
            animation: fadeIn 0.8s ease-out 1.4s both;
        }

        .info-item {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            margin: 12px 0;
            color: #64748b;
            font-size: 14px;
            transition: all 0.3s ease;
            padding: 8px;
            border-radius: 10px;
        }

        .info-item:hover {
            color: #94a3b8;
            background: rgba(139, 92, 246, 0.05);
        }

        .info-icon {
            width: 20px;
            height: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
        }

        #countdown {
            color: #8b5cf6;
            font-weight: 700;
        }
    </style>
</head>
<body>
    <div class="orb orb1"></div>
    <div class="orb orb2"></div>
    <div class="orb orb3"></div>
    
    <div class="error-box">
        <div class="icon-wrapper"></div>
        <h2>Something went wrong</h2>
        <p>We are having trouble connecting to the system.</p>
        <p>Please try again later or <a href="#" class="contact-link">contact the administrator</a>.</p>
       
        <div class="error-code">ERROR: CONNECTION_TIMEOUT_503</div>
        
        <div class="status-indicator">
            <span class="status-dot"></span>
            <span>System Status: Offline</span>
        </div>
        
        <div class="additional-info">
            <div class="info-item">
                <span class="info-icon">🕐</span>
                <span id="timestamp"></span>
            </div>
            <div class="info-item">
                <span class="info-icon">📍</span>
                <span>Server: Philippines (PH-01)</span>
            </div>
            <div class="info-item">
                <span class="info-icon">🔄</span>
                <span>Auto-retry in <span id="countdown">30</span>s</span>
            </div>
        </div>
    </div>

    <script>
        // Display current timestamp
        function updateTimestamp() {
            const now = new Date();
            const timeString = now.toLocaleTimeString('en-US', { 
                hour: '2-digit', 
                minute: '2-digit',
                second: '2-digit'
            });
            const dateString = now.toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
                year: 'numeric'
            });
            document.getElementById('timestamp').textContent = `${dateString} at ${timeString}`;
        }
        
        updateTimestamp();
        setInterval(updateTimestamp, 1000);

        // Countdown timer
        let countdown = 30;
        const countdownInterval = setInterval(() => {
            countdown--;
            document.getElementById('countdown').textContent = countdown;
            
            if (countdown <= 0) {
                clearInterval(countdownInterval);
                // Auto retry
                handleRetry(document.querySelector('.retry-button'));
            }
        }, 1000);

        function handleRetry(button) {
            button.classList.add('loading');
            button.disabled = true;
            
            // Reset countdown
            countdown = 30;
            clearInterval(countdownInterval);
            
            // Simulate retry attempt
            setTimeout(() => {
                button.classList.remove('loading');
                button.disabled = false;
                // In a real scenario, you would reload the page or retry the connection
                // window.location.reload();
                
                // Restart countdown
                countdown = 30;
            }, 2000);
        }
    </script>
</body>
</html>