<?php
/* ============================================================
   The one page that has to work when nothing else does.

   includes/db_connect.php includes this from its catch block and
   exits, so by the time it renders the database is unreachable —
   which rules out systemConfig.php (the system name, the uploaded
   logo and the footer all live in tables) and rules out anything
   else that needs a query. Everything below is static on purpose,
   and nothing is fetched from a CDN: the old page pulled its
   favicon off flaticon.com, which is one more thing to be down.

   It also renders from ANY depth: db_connect.php is included from
   the web root (index.php), from pages/, Qrscanner/, crud/ and
   includes/. A relative "assets/..." href would therefore resolve
   differently on every caller, which is why the base URL is worked
   out from __DIR__ rather than written by hand. includes/asset.php
   cannot help here — it versions against dirname(SCRIPT_FILENAME),
   and SCRIPT_FILENAME is whichever page happened to fail.

   Colours: no literal neutrals. The page reads the same
   --bg/--surface/--ink/--line tokens as the rest of the app and
   follows light and dark with it — it used to be dark-only, on a
   purple gradient that appears nowhere else in the system. Each
   var() carries a dark fallback so that if theme.css is the thing
   that cannot be reached, the page still looks deliberate rather
   than unstyled.
   ============================================================ */

/* A database outage is not a 200. Monitors and crawlers read this;
   Retry-After matches the countdown in the card. Guarded because a
   page that had already begun printing can fail mid-render. */
if (!headers_sent()) {
    http_response_code(503);
    header('Retry-After: 30');
}

date_default_timezone_set('Asia/Manila');

/* db_connect.php writes its own line to includes/db_error.log
   stamped Y-m-d H:i:s. This reference is the same moment in a form
   short enough to read down a phone, so a report of "it says
   0818-1432" points the administrator at the right log line.
   Nothing secret is in it — it is a timestamp, not a token. */
$errorReference = date('md-Hi');
$errorStamp     = date('d M Y · H:i');

/* Fill this in to turn "contact the administrator" into a real
   mailto with the reference already in the subject. Left empty
   rather than guessed: a dead link that looks live is worse than
   plain text, and the address cannot be read from the settings
   table while the database is the thing that is down. */
$supportEmail = '';

/* Where this file sits relative to the web root, so the stylesheet,
   the seal and the "back to sign in" link resolve from every
   caller. When the two paths do not line up (a symlinked docroot,
   an unusual host) $appBase stays '/' and the var() fallbacks
   below carry the page on their own. */
$appBase = '/';
$selfDir = str_replace('\\', '/', __DIR__);
$docRoot = isset($_SERVER['DOCUMENT_ROOT']) ? realpath($_SERVER['DOCUMENT_ROOT']) : false;
$docRoot = $docRoot ? rtrim(str_replace('\\', '/', $docRoot), '/') : '';

if ($docRoot !== '' && strpos($selfDir, $docRoot) === 0) {
    $appBase = rtrim(substr($selfDir, strlen($docRoot)), '/') . '/';
}

/* Same cache-busting idea as includes/asset.php, but measured from
   __DIR__ because this file knows where it is and the failing
   script does not. */
$themeHref = $appBase . 'assets/css/theme.css';
$themeTime = @filemtime(__DIR__ . '/assets/css/theme.css');
if ($themeTime) {
    $themeHref .= '?v=' . $themeTime;
}
?>
<!doctype html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
    <meta name="theme-color" content="#0f172a">
    <meta name="robots" content="noindex">
    <title>System unavailable | BCC SASQR</title>
    <link rel="icon" type="image/png" href="<?= htmlspecialchars($appBase) ?>assets/images/bcc-logo.png">

    <!-- The same pre-paint theme resolution every other page uses
         (includes/theme_head.php). Inlined rather than included:
         that file builds its href with asset(), which needs the
         caller's directory, and the caller here is whatever page
         just failed. -->
    <script>
        (function () {
            try {
                var saved = localStorage.getItem('bcc-theme');
                var theme = (saved === 'light' || saved === 'dark')
                    ? saved
                    : (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
                document.documentElement.setAttribute('data-theme', theme);
            } catch (e) {
                document.documentElement.setAttribute('data-theme', 'dark');
            }
        })();
    </script>

    <link rel="stylesheet" href="<?= htmlspecialchars($themeHref) ?>">

    <style>
        *,
        *::before,
        *::after {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        .err-page {
            min-height: 100dvh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px 16px;
            padding-top: max(24px, env(safe-area-inset-top));
            padding-bottom: max(24px, env(safe-area-inset-bottom));
            background: var(--bg, #0f0f13);
            color: var(--ink-3, #cbd5e1);
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            /* The old page pinned height:100vh with overflow:hidden, so
               on a short phone in landscape the card was cut off with no
               way to scroll down to the rest of it. */
            overflow-x: hidden;
        }

        /* ── Ground ───────────────────────────────────────────────
           Two static washes behind the card instead of three blurred
           orbs on a 20s float loop and a drifting dot field. The red
           says fault before a word is read; it does not have to move
           to do it. --tint is 15,23,42 in light and 255,255,255 in
           dark, which is exactly what a texture layer wants. */
        .err-veil {
            position: fixed;
            inset: 0;
            z-index: 0;
            pointer-events: none;
            background:
                radial-gradient(60% 45% at 50% 0%, rgba(239, 68, 68, .16), transparent 70%),
                radial-gradient(50% 40% at 50% 100%, rgba(102, 126, 234, .10), transparent 70%);
        }

        .err-veil::after {
            content: '';
            position: absolute;
            inset: 0;
            background-image: radial-gradient(circle, rgba(var(--tint, 255, 255, 255), .10) 1px, transparent 1px);
            background-size: 44px 44px;
            -webkit-mask-image: radial-gradient(ellipse 70% 60% at 50% 50%, #000, transparent 75%);
            mask-image: radial-gradient(ellipse 70% 60% at 50% 50%, #000, transparent 75%);
            opacity: .7;
        }

        /* ── The card ─────────────────────────────────────────────
           Same shape language as the login card and the face modal:
           --surface, a --line hairline, a 20px radius and one soft
           drop shadow. */
        .err-card {
            position: relative;
            z-index: 1;
            width: 100%;
            max-width: 460px;
            padding: 34px 30px 28px;
            text-align: center;
            border: 1px solid var(--line, rgba(255, 255, 255, .12));
            border-radius: 20px;
            background: var(--surface, #16161a);
            box-shadow: 0 30px 70px -20px var(--shadow-lg, rgba(0, 0, 0, .5));
            animation: errRise .45s cubic-bezier(.22, 1, .36, 1) both;
        }

        @keyframes errRise {
            from { opacity: 0; transform: translateY(18px); }
            to   { opacity: 1; transform: none; }
        }

        /* ── Brand line ───────────────────────────────────────────
           Small and muted: the point of it is that the user can see
           WHICH system is down. Only "QR" is tinted — the same two
           letters the login wordmark tints. */
        .err-brand {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            margin-bottom: 26px;
        }

        .err-brand img {
            width: 30px;
            height: 30px;
            object-fit: contain;
        }

        .err-brand span {
            font-size: .95rem;
            font-weight: 700;
            letter-spacing: .14em;
            color: var(--ink-4, rgba(255, 255, 255, .45));
        }

        .err-brand b {
            color: #38bdf8;
            font-weight: 700;
        }

        /* ── Fault mark ───────────────────────────────────────────
           A struck-through database, not a generic ⚠ — this page has
           exactly one cause, and naming it in the icon saves a line
           of text. It replaces an emoji glyph that also carried a
           shake, a pulse and a ripple, three infinite animations on
           one 90px circle. */
        .err-icon {
            width: 78px;
            height: 78px;
            margin: 0 auto 22px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 50%;
            background: linear-gradient(135deg, #ef4444, #b91c1c);
            box-shadow: 0 12px 30px -8px rgba(239, 68, 68, .55),
                        0 0 0 8px rgba(239, 68, 68, .10);
        }

        .err-icon svg {
            width: 40px;
            height: 40px;
            display: block;
        }

        .err-card h1 {
            margin-bottom: 12px;
            font-size: 1.5rem;
            font-weight: 700;
            line-height: 1.25;
            letter-spacing: -.02em;
            color: var(--ink, #ffffff);
        }

        .err-lede {
            font-size: .95rem;
            line-height: 1.65;
            color: var(--ink-3, #cbd5e1);
        }

        .err-lede + .err-lede {
            margin-top: 8px;
            font-size: .88rem;
            color: var(--ink-4, rgba(255, 255, 255, .45));
        }

        .err-contact {
            color: #38bdf8;
            font-weight: 600;
            text-decoration: none;
            border-bottom: 1px solid transparent;
            transition: border-color .2s ease;
        }

        .err-contact:hover,
        .err-contact:focus-visible {
            border-bottom-color: currentColor;
        }

        /* ── Status chip ──────────────────────────────────────────
           Says what actually failed. The page used to print
           "ERROR: CONNECTION_TIMEOUT_503" beside "Server: Philippines
           (PH-01)" — both hard-coded, neither measured, and neither
           true of a refused database connection. */
        .err-status {
            display: inline-flex;
            align-items: center;
            gap: 9px;
            margin-top: 20px;
            padding: 8px 15px;
            border: 1px solid rgba(239, 68, 68, .45);
            border-radius: 999px;
            background: rgba(239, 68, 68, .12);
            color: var(--bad-ink, #fca5a5);
            font-size: .82rem;
            font-weight: 600;
        }

        .err-dot {
            width: 8px;
            height: 8px;
            flex-shrink: 0;
            border-radius: 50%;
            background: #ef4444;
            box-shadow: 0 0 8px rgba(239, 68, 68, .8);
            animation: errBlink 2s ease-in-out infinite;
        }

        @keyframes errBlink {
            0%, 100% { opacity: 1; }
            50%      { opacity: .25; }
        }

        /* ── Actions ──────────────────────────────────────────────
           The old markup had none: the script called
           document.querySelector('.retry-button') on a button that
           was never in the HTML, so the countdown ended in a
           TypeError and nothing was ever retried. */
        .err-actions {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 26px;
        }

        .err-btn {
            flex: 1 1 150px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 9px;
            min-height: 46px;
            padding: 12px 20px;
            border: 1px solid transparent;
            border-radius: 12px;
            font-family: inherit;
            font-size: .92rem;
            font-weight: 600;
            text-decoration: none;
            cursor: pointer;
            transition: transform .2s ease, filter .2s ease, background .2s ease, color .2s ease;
        }

        .err-btn svg {
            width: 17px;
            height: 17px;
            flex-shrink: 0;
        }

        .err-btn-primary {
            background: linear-gradient(135deg, #667eea, #5a67d8);
            color: var(--on-accent, #ffffff);
            box-shadow: 0 10px 24px -10px rgba(102, 126, 234, .8);
        }

        .err-btn-primary:hover {
            transform: translateY(-2px);
            filter: brightness(1.07);
        }

        .err-btn-ghost {
            border-color: var(--line, rgba(255, 255, 255, .12));
            background: var(--surface-2, #1a1a2e);
            color: var(--ink-3, #cbd5e1);
        }

        .err-btn-ghost:hover {
            background: var(--surface-3, #2a2a33);
            color: var(--ink, #ffffff);
        }

        .err-btn:active {
            transform: translateY(0) scale(.99);
        }

        .err-btn:focus-visible {
            outline: 2px solid #667eea;
            outline-offset: 2px;
        }

        .err-btn[disabled] {
            opacity: .65;
            pointer-events: none;
        }

        .err-spinner {
            width: 15px;
            height: 15px;
            border: 2px solid rgba(255, 255, 255, .35);
            border-top-color: #fff;
            border-radius: 50%;
            animation: errSpin .7s linear infinite;
        }

        @keyframes errSpin {
            to { transform: rotate(360deg); }
        }

        /* ── Footnotes ────────────────────────────────────────────
           A definition list, because that is what these are: three
           labelled values. The old markup used centred flex rows led
           by emoji, which read as decoration and handed a screen
           reader "alarm clock" where a label belonged. */
        .err-meta {
            display: grid;
            grid-template-columns: auto 1fr;
            gap: 9px 14px;
            margin-top: 24px;
            padding-top: 18px;
            border-top: 1px solid var(--line, rgba(255, 255, 255, .12));
            text-align: left;
            font-size: .8rem;
        }

        .err-meta dt {
            align-self: center;
            color: var(--ink-5, rgba(255, 255, 255, .3));
            font-size: .7rem;
            letter-spacing: .07em;
            text-transform: uppercase;
        }

        .err-meta dd {
            color: var(--ink-4, rgba(255, 255, 255, .45));
            font-variant-numeric: tabular-nums;
        }

        .err-meta dd.err-ref {
            font-family: ui-monospace, "Cascadia Mono", "Segoe UI Mono", Consolas, monospace;
            letter-spacing: .04em;
            color: var(--ink-3, #cbd5e1);
        }

        #errCountdown {
            font-weight: 700;
            color: var(--ink-3, #cbd5e1);
            font-variant-numeric: tabular-nums;
        }

        @media (max-width: 420px) {
            .err-card {
                padding: 28px 22px 24px;
            }

            .err-card h1 {
                font-size: 1.3rem;
            }

            .err-actions .err-btn {
                flex-basis: 100%;
            }
        }

        /* Short landscape phones: let the card scroll from the top
           rather than centring half of it off-screen. */
        @media (max-height: 560px) and (orientation: landscape) {
            .err-page {
                align-items: flex-start;
            }
        }

        @media (hover: none) {
            .err-btn:hover {
                transform: none;
                filter: none;
            }
        }

        @media (prefers-reduced-motion: reduce) {
            *,
            *::before,
            *::after {
                animation: none !important;
                transition-duration: .01ms !important;
            }
        }
    </style>
</head>

<body class="err-page">
    <div class="err-veil" aria-hidden="true"></div>

    <main class="err-card">

        <div class="err-brand">
            <img src="<?= htmlspecialchars($appBase) ?>assets/images/bcc-logo.png" alt="" width="30" height="30">
            <span>SAS<b>QR</b></span>
        </div>

        <div class="err-icon" aria-hidden="true">
            <svg viewBox="0 0 48 48" fill="none" stroke="#ffffff" stroke-width="3"
                 stroke-linecap="round" stroke-linejoin="round">
                <ellipse cx="24" cy="12" rx="13" ry="5" />
                <path d="M11 12v11c0 2.8 5.8 5 13 5s13-2.2 13-5V12" />
                <path d="M11 23v11c0 2.8 5.8 5 13 5s13-2.2 13-5V23" />
                <!-- The slash is drawn twice: once wide in the disc's own
                     red, so it cuts a clean gap through the cylinder
                     instead of just crossing over it, then once narrow
                     in white on top. -->
                <path d="M13 38 35 8" stroke="#cf2f2f" stroke-width="8" />
                <path d="M13 38 35 8" />
            </svg>
        </div>

        <h1>We can&rsquo;t reach the system</h1>

        <p class="err-lede">
            The attendance database is not responding, so nothing can be loaded or saved right now.
        </p>
        <p class="err-lede">
            Nothing you submitted was lost &mdash; it never went through. Try again in a moment<?php if ($supportEmail !== ''): ?>,
            or <a class="err-contact" href="mailto:<?= htmlspecialchars($supportEmail) ?>?subject=<?= rawurlencode('SASQR outage · ref ' . $errorReference) ?>">contact the administrator</a><?php else: ?>,
            or give the system administrator the reference below<?php endif; ?>.
        </p>

        <div class="err-status">
            <span class="err-dot" aria-hidden="true"></span>
            <span>Database unreachable</span>
        </div>

        <div class="err-actions">
            <button type="button" class="err-btn err-btn-primary" id="errRetry">
                <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M8 3a5 5 0 1 0 4.546 2.914.5.5 0 0 1 .908-.417A6 6 0 1 1 8 2z" />
                    <path d="M8 4.466V.534a.25.25 0 0 1 .41-.192l2.36 1.966c.12.1.12.284 0 .384L8.41 4.658A.25.25 0 0 1 8 4.466" />
                </svg>
                <span id="errRetryLabel">Try again</span>
            </button>

            <a class="err-btn err-btn-ghost" href="<?= htmlspecialchars($appBase) ?>index.php">
                <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M15 8a.5.5 0 0 0-.5-.5H2.707l3.147-3.146a.5.5 0 1 0-.708-.708l-4 4a.5.5 0 0 0 0 .708l4 4a.5.5 0 0 0 .708-.708L2.707 8.5H14.5A.5.5 0 0 0 15 8" />
                </svg>
                Back to sign in
            </a>
        </div>

        <dl class="err-meta">
            <dt>Reference</dt>
            <dd class="err-ref"><?= htmlspecialchars($errorReference) ?></dd>

            <dt>Time</dt>
            <dd><?= htmlspecialchars($errorStamp) ?></dd>

            <dt>Retry</dt>
            <dd id="errRetryLine">Automatically in <span id="errCountdown">30</span>s</dd>
        </dl>
    </main>

    <script>
        (function () {
            'use strict';

            var RETRY_SECONDS = 30;
            var MAX_AUTO_RETRIES = 3;

            var retryBtn = document.getElementById('errRetry');
            var retryLabel = document.getElementById('errRetryLabel');
            var countdownEl = document.getElementById('errCountdown');
            var retryLine = document.getElementById('errRetryLine');

            function reload() {
                retryBtn.disabled = true;
                retryLabel.textContent = 'Reconnecting';
                retryBtn.insertAdjacentHTML('beforeend', '<span class="err-spinner"></span>');
                window.location.reload();
            }

            retryBtn.addEventListener('click', function () {
                /* A manual attempt is the person taking over, so the
                   automatic budget below resets with it. */
                try { sessionStorage.removeItem('bcc-error-retries'); } catch (e) {}
                reload();
            });

            /* Auto-retry, but not forever. Each reload runs this script
               again, so without a budget a sustained outage would have
               every open tab reloading every 30 seconds for as long as
               it lasted — against a database that is already refusing
               connections. After three tries it stops and waits. */
            var attempts = 0;
            try {
                attempts = parseInt(sessionStorage.getItem('bcc-error-retries') || '0', 10) || 0;
            } catch (e) {}

            if (attempts >= MAX_AUTO_RETRIES) {
                retryLine.textContent = 'Stopped after ' + MAX_AUTO_RETRIES + ' automatic attempts';
                return;
            }

            var left = RETRY_SECONDS;
            var timer = setInterval(function () {
                left--;

                if (left <= 0) {
                    clearInterval(timer);
                    try {
                        sessionStorage.setItem('bcc-error-retries', String(attempts + 1));
                    } catch (e) {}
                    reload();
                    return;
                }

                countdownEl.textContent = left;
            }, 1000);
        })();
    </script>
</body>

</html>
