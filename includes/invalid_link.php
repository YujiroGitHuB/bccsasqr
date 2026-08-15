<?php require_once __DIR__ . '/../includes/asset.php'; ?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><?= (($invalid_reason ?? '') === 'expired') ? 'Attendance Link Closed' : 'Invalid Attendance Link' ?></title>
    <link rel="shortcut icon" href="../assets/images/bcc logo.png" type="image/x-icon">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <link href="https://fonts.googleapis.com/css2?family=Sora:wght@300;400;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet" />
    <style>
        *,
        *::before,
        *::after {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --bg: #0b0e14;
            --surface: #12161f;
            --border: #1e2433;
            --accent: #ff0000;
            --accent-dim: #f03b3b22;
            --muted: #ffffff;
            --text: #ffffff;
            --heading: #eef0f8;
        }

        body {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: var(--bg);
            font-family: 'Sora', sans-serif;
            color: var(--text);
            padding: 1.5rem;
            overflow: hidden;
        }

        /* ── Background radial pulse ── */
        body::before {
            content: '';
            position: fixed;
            top: -20%;
            left: 50%;
            transform: translateX(-50%);
            width: 600px;
            height: 600px;
            background: radial-gradient(circle, #f05c3b22 0%, transparent 65%);
            pointer-events: none;
            animation: pulse 5s ease-in-out infinite;
        }

        @keyframes pulse {

            0%,
            100% {
                opacity: 0.6;
                transform: translateX(-50%) scale(1);
            }

            50% {
                opacity: 1.0;
                transform: translateX(-50%) scale(1.15);
            }
        }

        /* ── Floating particles ── */
        .particles {
            position: fixed;
            inset: 0;
            pointer-events: none;
            overflow: hidden;
        }

        .particle {
            position: absolute;
            border-radius: 50%;
            background: radial-gradient(circle, #ff4444aa, transparent);
            animation: floatUp linear infinite;
        }

        @keyframes floatUp {
            0% {
                transform: translateY(110vh) scale(0);
                opacity: 0;
            }

            10% {
                opacity: 1;
            }

            90% {
                opacity: 0.4;
            }

            100% {
                transform: translateY(-10vh) scale(1.2);
                opacity: 0;
            }
        }

        /* ── Card ── */
        .card {
            position: relative;
            background: var(--surface);
            border-left: 1px solid var(--accent);
            border-right: 1px solid var(--accent);
            border-bottom: 1px solid var(--accent);
            border-radius: 20px;
            padding: 3rem 2.5rem 2.5rem;
            max-width: 440px;
            width: 100%;
            text-align: center;
            box-shadow:
                0 0 20px rgba(255, 0, 0, 0.3),
                0 0 40px rgba(255, 38, 0, 0.2),
                inset 0 0 50px rgba(0, 0, 0, 0.5);
            animation: slideUp 0.55s cubic-bezier(0.22, 1, 0.36, 1) both,
                cardShake 0.6s 0.6s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
            overflow: hidden;
        }

        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(40px);
            }

            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        @keyframes cardShake {

            0%,
            100% {
                transform: translateX(0);
            }

            15% {
                transform: translateX(-6px);
            }

            30% {
                transform: translateX(6px);
            }

            45% {
                transform: translateX(-4px);
            }

            60% {
                transform: translateX(4px);
            }

            75% {
                transform: translateX(-2px);
            }

            90% {
                transform: translateX(2px);
            }
        }

        /* Top accent line */
        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 10%;
            right: 10%;
            height: 2px;
            background: linear-gradient(90deg, transparent, var(--accent), transparent);
            border-radius: 2px;
        }

        /* ── Icon ── */
        .icon-wrap {
            width: 72px;
            height: 72px;
            margin: 0 auto 1.75rem;
            background: var(--accent-dim);
            border: 1px solid #f05c3b44;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            animation: iconPop 0.6s 0.3s cubic-bezier(0.34, 1.56, 0.64, 1) both,
                iconPulseRing 2.5s 1.5s ease-out infinite;
            position: relative;
        }

        /* ring ripple */
        .icon-wrap::after {
            content: '';
            position: absolute;
            inset: -1px;
            border-radius: 50%;
            border: 1px solid #ff4444;
            animation: ringRipple 2.5s 1.5s ease-out infinite;
        }

        @keyframes ringRipple {
            0% {
                transform: scale(1);
                opacity: 0.7;
            }

            100% {
                transform: scale(1.9);
                opacity: 0;
            }
        }

        @keyframes iconPop {
            from {
                opacity: 0;
                transform: scale(0.4) rotate(-15deg);
            }

            to {
                opacity: 1;
                transform: scale(1) rotate(0deg);
            }
        }

        @keyframes iconPulseRing {

            0%,
            100% {
                box-shadow: 0 0 0 0 #ff444433;
            }

            50% {
                box-shadow: 0 0 0 10px transparent;
            }
        }

        /* SVG X lines draw-in */
        .icon-wrap svg .x-line {
            stroke-dasharray: 10;
            stroke-dashoffset: 10;
            animation: drawLine 0.4s 0.9s ease forwards;
        }

        .icon-wrap svg .x-line:nth-child(2) {
            animation-delay: 1.05s;
        }

        @keyframes drawLine {
            to {
                stroke-dashoffset: 0;
            }
        }

        /* ── Badge ── */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            background: var(--accent-dim);
            border: 1px solid #f05c3b33;
            color: var(--accent);
            font-family: 'JetBrains Mono', monospace;
            font-size: 0.68rem;
            font-weight: 500;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            padding: 0.3rem 0.8rem;
            border-radius: 100px;
            margin-bottom: 1.25rem;
            animation: fadeIn 0.5s 0.4s both;
        }

        .badge-dot {
            width: 6px;
            height: 6px;
            background: var(--accent);
            border-radius: 50%;
            animation: blink 1.5s ease-in-out infinite;
        }

        @keyframes blink {

            0%,
            100% {
                opacity: 1;
            }

            50% {
                opacity: 0.2;
            }
        }

        /* ── Glitch heading ── */
        h1 {
            font-size: 1.55rem;
            font-weight: 700;
            color: var(--heading);
            letter-spacing: -0.02em;
            line-height: 1.25;
            margin-bottom: 0.85rem;
            position: relative;
            animation: fadeIn 0.5s 0.5s both, glitchLoop 6s 1.5s ease-in-out infinite;
        }

        h1::before,
        h1::after {
            content: attr(data-text);
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            overflow: hidden;
            clip-path: inset(0 0 0 0);
        }

        h1::before {
            color: #ff3333;
            animation: glitchTop 6s 1.5s ease-in-out infinite;
            text-shadow: -2px 0 #00ffff;
        }

        h1::after {
            color: #0099ff;
            animation: glitchBot 6s 1.5s ease-in-out infinite;
            text-shadow: 2px 0 #ff0066;
        }

        @keyframes glitchLoop {

            0%,
            90%,
            100% {
                transform: none;
            }

            91% {
                transform: skewX(-2deg);
            }

            92% {
                transform: skewX(2deg);
            }

            93% {
                transform: none;
            }

            95% {
                transform: skewX(-1deg);
            }

            96% {
                transform: none;
            }
        }

        @keyframes glitchTop {

            0%,
            90%,
            100% {
                clip-path: inset(100% 0 0 0);
                transform: none;
            }

            91% {
                clip-path: inset(10% 0 60% 0);
                transform: translateX(-4px);
            }

            92% {
                clip-path: inset(45% 0 30% 0);
                transform: translateX(4px);
            }

            93% {
                clip-path: inset(100% 0 0 0);
                transform: none;
            }
        }

        @keyframes glitchBot {

            0%,
            90%,
            100% {
                clip-path: inset(0 0 100% 0);
                transform: none;
            }

            91% {
                clip-path: inset(60% 0 5% 0);
                transform: translateX(4px);
            }

            92% {
                clip-path: inset(30% 0 40% 0);
                transform: translateX(-4px);
            }

            93% {
                clip-path: inset(0 0 100% 0);
                transform: none;
            }
        }

        p {
            font-size: 0.915rem;
            font-weight: 300;
            color: var(--text);
            line-height: 1.7;
            animation: fadeIn 0.5s 0.6s both;
        }

        .divider {
            height: 1px;
            background: var(--border);
            margin: 1.75rem 0;
            animation: fadeIn 0.5s 0.65s both;
        }

        /* ── Info box ── */
        .info-box {
            display: flex;
            align-items: flex-start;
            gap: 0.85rem;
            background: #0b0e1488;
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 1rem 1.1rem;
            text-align: left;
            animation: fadeIn 0.5s 0.7s both;
            transition: border-color 0.3s;
        }

        .info-box:hover {
            border-color: #ff444444;
        }

        .info-box svg {
            flex-shrink: 0;
            width: 18px;
            height: 18px;
            stroke: var(--muted);
            margin-top: 1px;
        }

        .info-box span {
            font-size: 0.84rem;
            color: var(--muted);
            line-height: 1.6;
        }

        .info-box strong {
            color: #f03b3b;
            font-weight: 500;
        }
    </style>
</head>

<body>

    <!-- Floating particles -->
    <div class="particles" id="particles"></div>

    <div class="card">
        <div class="scan-line"></div>

        <div class="icon-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                <line class="x-line" x1="9" y1="9" x2="15" y2="15" />
                <line class="x-line" x1="15" y1="9" x2="9" y2="15" />
            </svg>
        </div>

        <?php
        // Tatlong magkakaibang balita ang dating iisa ang teksto. Para sa
        // estudyanteng nakatayo sa labas ng silid, malaki ang pagkakaiba
        // ng "mali ang link" at ng "tapos na ang oras" — ang una ay
        // ipapa-check muli ang URL, ang ikalawa ay dapat nang lumapit sa
        // instructor. Nakatakda ng pages/daily_attendance.php ang
        // $invalid_reason; nananatili ang lumang teksto kung hindi.
        $reason = $invalid_reason ?? 'unknown';

        $copy = [
            'expired'  => [
                'badge' => 'Link Expired',
                'title' => 'Attendance Link Closed',
                'text'  => 'The time window for this attendance link has ended. It is no longer accepting submissions.',
            ],
            'inactive' => [
                'badge' => 'Link Deactivated',
                'title' => 'Attendance Link Deactivated',
                'text'  => 'Your instructor has turned this link off.',
            ],
            'unknown'  => [
                'badge' => 'Link Deactivated',
                'title' => 'Invalid Attendance Link',
                'text'  => 'This link is either invalid or has been deactivated by your instructor.',
            ],
        ][$reason] ?? null;

        $copy = $copy ?? [
            'badge' => 'Link Deactivated',
            'title' => 'Invalid Attendance Link',
            'text'  => 'This link is either invalid or has been deactivated by your instructor.',
        ];
        ?>

        <div class="badge"><span class="badge-dot"></span> <?= htmlspecialchars($copy['badge']) ?></div>

        <h1 data-text="<?= htmlspecialchars($copy['title']) ?>"><?= htmlspecialchars($copy['title']) ?></h1>
        <p><?= htmlspecialchars($copy['text']) ?></p>

        <div class="divider"></div>

        <div class="info-box">
            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            <span>Please <strong>contact your instructor</strong> to request a new attendance link for your session.</span>
        </div>
    </div>

    <script src="<?= asset('../assets/js/detection.js') ?>"></script>
    <script>
        /* ── Floating particles ── */
        const container = document.getElementById('particles');
        for (let i = 0; i < 18; i++) {
            const p = document.createElement('div');
            p.className = 'particle';
            const size = Math.random() * 6 + 3;
            p.style.cssText = `
                width: ${size}px; height: ${size}px;
                left: ${Math.random() * 100}%;
                animation-duration: ${Math.random() * 8 + 7}s;
                animation-delay: ${Math.random() * 6}s;
                opacity: ${Math.random() * 0.5 + 0.1};
            `;
            container.appendChild(p);
        }
    </script>
</body>

</html>