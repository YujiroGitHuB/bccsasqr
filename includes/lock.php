<?php include __DIR__ . "/../includes/systemConfig.php";?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Temporarily Locked</title>
    <link rel="icon" type="image/png" href="../<?php echo $systemLogo;?>">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600&display=swap" rel="stylesheet">
    <style>
        /* Background Gradient */
        body {
            background: linear-gradient(135deg, #0f172a, #1e293b);
            color: #f1f5f9;
            font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            text-align: center;
            padding: 8vh 5vw;
            margin: 0;
        }

        /* Lock Box */
        .lock-box {
            background: #1e293b;
            display: inline-block;
            padding: 4em 3em;
            border-radius: 2em;
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.5);
            max-width: 500px;
            width: 100%;
            margin: 0 auto;
            box-sizing: border-box;
            animation: fadeInScale 0.8s ease-out;
        }

        @keyframes fadeInScale {
            0% {
                transform: scale(0.8);
                opacity: 0;
            }

            100% {
                transform: scale(1);
                opacity: 1;
            }
        }

        /* Emoji */
        .emoji {
            font-size: 5em;
            display: inline-block;
            animation: bounceGlow 1.8s infinite;
            margin-bottom: 0.5em;
            color: #38bdf8;
            text-shadow: 0 0 15px rgba(56, 189, 248, 0.7), 0 0 30px rgba(56, 189, 248, 0.4);
        }

        @keyframes bounceGlow {

            0%,
            100% {
                transform: translateY(0);
                text-shadow: 0 0 15px rgba(56, 189, 248, 0.7), 0 0 30px rgba(56, 189, 248, 0.4);
            }

            50% {
                transform: translateY(-10px);
                text-shadow: 0 0 25px rgba(56, 189, 248, 0.9), 0 0 45px rgba(56, 189, 248, 0.6);
            }
        }

        /* Headings and Text */
        h1 {
            color: #38bdf8;
            font-size: 2.2em;
            margin-bottom: 0.6em;
            font-weight: 600;
            animation: slideFade 1s ease forwards;
        }

        p {
            margin: 0.8em 0;
            line-height: 1.7;
            font-size: 1em;
            animation: slideFade 1s ease forwards;
        }

        /* Fade/slide animation for text */
        @keyframes slideFade {
            0% {
                opacity: 0;
                transform: translateY(10px);
            }

            100% {
                opacity: 1;
                transform: translateY(0);
            }
        }

        /* Buttons */
        .contact-btn {
            display: inline-block;
            background: linear-gradient(135deg, #38bdf8, #0ea5e9);
            color: #0f172a;
            font-weight: 600;
            padding: 0.9em 2em;
            margin: 0.5em;
            border-radius: 1em;
            text-decoration: none;
            transition: all 0.3s ease;
            box-shadow: 0 8px 20px rgba(56, 189, 248, 0.4);
            animation: slideFade 1s ease forwards;
        }

        .contact-btn:hover {
            transform: translateY(-3px);
            box-shadow: 0 12px 30px rgba(56, 189, 248, 0.6);
        }

        /* Mobile Responsiveness */
        @media (max-width: 500px) {
            .lock-box {
                padding: 3em 2em;
                width: 90%;
            }

            h1 {
                font-size: 1.6em;
            }

            .emoji {
                font-size: 4em;
            }

            p {
                font-size: 0.95em;
            }

            .contact-btn {
                display: block;
                width: 80%;
                margin: 0.5em auto;
            }
        }
    </style>
</head>

<body>
    <div class="lock-box">
        <div class="emoji">🔒</div>
        <h1>Page Temporarily Locked</h1>
        <p>This page is currently restricted due to maintenance or security reasons.</p>
        <p>If you need access, please contact the developer through:</p>
        <a class="contact-btn" href="https://www.facebook.com/charlesnixon.cayading" target="_blank">Facebook</a>
        <a class="contact-btn" href="https://m.me/charlesnixon.cayading" target="_blank">Messenger</a>
        <p>Thank you for your understanding.</p>
    </div>
</body>

</html>