<?php if ($is_locked): ?>
    <div class="locked-overlay">
        <div class="locked-message">
            <div class="lock-icon-container">
                <div class="lock-glow"></div>
                <i class="bi bi-lock-fill locked-icon"></i>
                <div class="lock-particles">
                    <div class="particle"></div>
                    <div class="particle"></div>
                    <div class="particle"></div>
                    <div class="particle"></div>
                    <div class="particle"></div>
                    <div class="particle"></div>
                </div>
            </div>
            
            <h2 class="locked-title">Attendance Form Locked</h2>
            <p class="locked-description">The attendance form is currently locked and not accepting submissions.</p>
            <p class="locked-contact">Please contact your instructor or administrator for more information.</p>
            
            <button class="refresh-btn" onclick="window.location.reload()">
                <div class="btn-glow"></div>
                <i class="bi bi-arrow-clockwise"></i>
                <span>Refresh Page</span>
            </button>

            <div class="locked-footer">
                <i class="bi bi-shield-lock-fill"></i>
                <span>System Protected</span>
            </div>
        </div>

        <!-- Background Animation -->
        <div class="bg-animation">
            <div class="bg-particle"></div>
            <div class="bg-particle"></div>
            <div class="bg-particle"></div>
            <div class="bg-particle"></div>
            <div class="bg-particle"></div>
        </div>
    </div>

    <style>
        .locked-overlay {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #0f172a 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 9999;
            overflow: hidden;
        }

        /* Background Animation */
        .bg-animation {
            position: absolute;
            width: 100%;
            height: 100%;
            overflow: hidden;
        }

        .bg-particle {
            position: absolute;
            width: 4px;
            height: 4px;
            background: rgba(59, 130, 246, 0.5);
            border-radius: 50%;
            box-shadow: 0 0 10px rgba(59, 130, 246, 0.5);
        }

        .bg-particle:nth-child(1) {
            top: 20%;
            left: 20%;
            animation: float 8s infinite ease-in-out;
        }

        .bg-particle:nth-child(2) {
            top: 60%;
            left: 80%;
            animation: float 10s infinite ease-in-out 1s;
        }

        .bg-particle:nth-child(3) {
            top: 80%;
            left: 30%;
            animation: float 12s infinite ease-in-out 2s;
        }

        .bg-particle:nth-child(4) {
            top: 40%;
            left: 70%;
            animation: float 9s infinite ease-in-out 1.5s;
        }

        .bg-particle:nth-child(5) {
            top: 10%;
            left: 50%;
            animation: float 11s infinite ease-in-out 0.5s;
        }

        @keyframes float {
            0%, 100% {
                transform: translate(0, 0);
                opacity: 0.3;
            }
            25% {
                transform: translate(50px, -50px);
                opacity: 0.7;
            }
            50% {
                transform: translate(100px, 0);
                opacity: 0.3;
            }
            75% {
                transform: translate(50px, 50px);
                opacity: 0.7;
            }
        }

        /* Main Message Card */
        .locked-message {
            background: rgba(30, 41, 59, 0.8);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            padding: 60px 50px;
            border-radius: 30px;
            text-align: center;
            max-width: 550px;
            width: 90%;
            box-shadow: 
                0 0 0 1px rgba(148, 163, 184, 0.1),
                0 20px 60px rgba(0, 0, 0, 0.5),
                0 0 100px rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(148, 163, 184, 0.1);
            position: relative;
            z-index: 10;
            animation: slideUp 0.6s ease-out;
        }

        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        /* Lock Icon Container */
        .lock-icon-container {
            position: relative;
            width: 120px;
            height: 120px;
            margin: 0 auto 30px;
        }

        .lock-glow {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 140px;
            height: 140px;
            background: radial-gradient(circle, rgba(239, 68, 68, 0.3) 0%, transparent 70%);
            border-radius: 50%;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% {
                transform: translate(-50%, -50%) scale(1);
                opacity: 0.5;
            }
            50% {
                transform: translate(-50%, -50%) scale(1.2);
                opacity: 0.8;
            }
        }

        .locked-icon {
            position: relative;
            font-size: 80px;
            color: #ef4444;
            filter: drop-shadow(0 0 20px rgba(239, 68, 68, 0.6));
            animation: shake 3s infinite;
            z-index: 2;
        }

        @keyframes shake {
            0%, 100% { 
                transform: rotate(0deg); 
            }
            10%, 30%, 50%, 70%, 90% { 
                transform: rotate(-5deg); 
            }
            20%, 40%, 60%, 80% { 
                transform: rotate(5deg); 
            }
        }

        /* Lock Particles */
        .lock-particles {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
        }

        .particle {
            position: absolute;
            width: 6px;
            height: 6px;
            background: #ef4444;
            border-radius: 50%;
            opacity: 0;
            animation: particleFloat 3s infinite;
        }

        .particle:nth-child(1) {
            top: 20%;
            left: 20%;
            animation-delay: 0s;
        }

        .particle:nth-child(2) {
            top: 80%;
            left: 30%;
            animation-delay: 0.5s;
        }

        .particle:nth-child(3) {
            top: 40%;
            left: 80%;
            animation-delay: 1s;
        }

        .particle:nth-child(4) {
            top: 70%;
            left: 70%;
            animation-delay: 1.5s;
        }

        .particle:nth-child(5) {
            top: 30%;
            left: 50%;
            animation-delay: 2s;
        }

        .particle:nth-child(6) {
            top: 60%;
            left: 10%;
            animation-delay: 2.5s;
        }

        @keyframes particleFloat {
            0% {
                opacity: 0;
                transform: translateY(0) scale(0.5);
            }
            50% {
                opacity: 1;
                transform: translateY(-30px) scale(1);
            }
            100% {
                opacity: 0;
                transform: translateY(-60px) scale(0.5);
            }
        }

        /* Text Styles */
        .locked-title {
            font-size: 32px;
            font-weight: 700;
            color: #f1f5f9;
            margin-bottom: 20px;
            text-shadow: 0 0 20px rgba(239, 68, 68, 0.3);
        }

        .locked-description {
            font-size: 18px;
            color: #cbd5e1;
            margin-bottom: 12px;
            line-height: 1.6;
        }

        .locked-contact {
            font-size: 15px;
            color: #94a3b8;
            margin-bottom: 35px;
        }

        /* Refresh Button */
        .refresh-btn {
            position: relative;
            background: linear-gradient(135deg, #3b82f6, #2563eb);
            color: white;
            border: none;
            padding: 15px 40px;
            font-size: 16px;
            font-weight: 600;
            border-radius: 15px;
            cursor: pointer;
            overflow: hidden;
            transition: all 0.3s ease;
            box-shadow: 0 10px 30px rgba(59, 130, 246, 0.3);
            display: inline-flex;
            align-items: center;
            gap: 10px;
        }

        .refresh-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 15px 40px rgba(59, 130, 246, 0.4);
        }

        .refresh-btn:active {
            transform: translateY(0);
        }

        .btn-glow {
            position: absolute;
            top: -50%;
            left: -50%;
            width: 200%;
            height: 200%;
            background: radial-gradient(circle, rgba(255, 255, 255, 0.3) 0%, transparent 70%);
            opacity: 0;
            transition: opacity 0.3s;
        }

        .refresh-btn:hover .btn-glow {
            opacity: 1;
            animation: rotate 4s linear infinite;
        }

        @keyframes rotate {
            from {
                transform: rotate(0deg);
            }
            to {
                transform: rotate(360deg);
            }
        }

        .refresh-btn i {
            font-size: 18px;
            transition: transform 0.3s;
        }

        .refresh-btn:hover i {
            transform: rotate(180deg);
        }

        /* Footer */
        .locked-footer {
            margin-top: 40px;
            padding-top: 25px;
            border-top: 1px solid rgba(148, 163, 184, 0.2);
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            color: #64748b;
            font-size: 14px;
        }

        .locked-footer i {
            font-size: 16px;
            color: #3b82f6;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .locked-message {
                padding: 40px 30px;
                max-width: 90%;
            }

            .locked-title {
                font-size: 26px;
            }

            .locked-description {
                font-size: 16px;
            }

            .lock-icon-container {
                width: 100px;
                height: 100px;
            }

            .locked-icon {
                font-size: 60px;
            }

            .refresh-btn {
                padding: 12px 30px;
                font-size: 15px;
            }
        }
    </style>
<?php endif; ?>
