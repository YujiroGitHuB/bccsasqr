/**
 * Universal In-App Browser Detector
 *
 * Lumalabas kapag binuksan ang isang link ng sistema mula sa loob ng
 * Messenger, Facebook, Instagram at iba pa — kung saan hindi
 * mapagkakatiwalaan ang camera, ang clipboard at ang pag-download.
 *
 * Ginagamit ng: pages/daily_attendance.php, includes/invalid_link.php,
 * QRgenerator/QRcode.php, student/StudentPhotoProfile.php,
 * Tracker/view.php
 *
 * Paggamit (hindi nagbago):
 *   1. SweetAlert2 muna
 *   2. <link rel="stylesheet" href="assets/css/detection.css">
 *   3. <script src="assets/js/detection.js"></script>   — kusang tumatakbo
 *
 * ── Ang binago sa anyo ──────────────────────────────────────
 * Nasa loob ng file na ito dati ang buong disenyo: mga inline style
 * sa bawat elemento ng HTML string, at dalawang <style> na
 * idinidikit sa <head> sa TUWING bubukas ang modal — hindi kailanman
 * inaalis, kaya naiipon. Walong magkakalapit na asul-lila ang
 * naipon doon, wala ni isa sa palette ng app, at lahat ay
 * nakakandado sa madilim: `background: '#0f172a'` kasabay ng
 * `color: '#000000'`, samantalang may light mode na ang sistema.
 *
 * Nasa assets/css/detection.css na ang lahat ng iyon.
 *
 * ── Ang binago sa nilalaman ─────────────────────────────────
 * Ang mga tagubilin ay Chrome at Android lamang: "Tap the 3 dots (⋮)
 * in the upper right corner". Walang tatlong tuldok sa itaas-kanan
 * ng Messenger sa iPhone, at walang Chrome ang karamihan sa kanila —
 * Safari ang nasa telepono nila. Sinusunod na nito ang platform.
 *
 * Ang babala ay hadlang at hindi paalala: walang "continue anyway" at
 * walang pagsasara sa labas. Pagkatapos kumopya ng link, sinusubukan
 * nitong ilabas ang estudyante sa in-app browser — at kung hindi
 * tumalab iyon, bumabalik ang babala. Sinasadya iyon: hindi gumagana
 * ang camera at ang pag-upload sa loob ng in-app browser, at hindi
 * sumusunod ang layout sa lapad ng telepono doon, kaya ang
 * pagpapatuloy ay hindi mas mababang antas ng serbisyo kundi isang
 * sirang pahina.
 *
 * Ang kapalit: isang regex sa user agent ang nagpapasya nito, kaya
 * ang maling tama ay nangangahulugang hindi makakapag-attendance ang
 * estudyante hangga't hindi siya lumilipat ng browser. Sa listahan sa
 * itaas dapat idagdag ang anumang app na dapat payagan.
 */

const BrowserDetector = (function () {
    'use strict';

    // ─── Detection ────────────────────────────────────────────
    function detectInAppBrowser() {
        const ua = navigator.userAgent || navigator.vendor || window.opera;

        const isInAppBrowser = {
            messenger: /\bFB[\w_]+\/(Messenger|MESSENGER)/.test(ua) || /\bMessengerLite/.test(ua),
            facebook: /\bFB[\w_]+\//.test(ua) && !/\bMessenger/.test(ua),
            instagram: /Instagram/.test(ua),
            tiktok: /TikTok/.test(ua),
            twitter: /Twitter/.test(ua),
            linkedin: /LinkedInApp/.test(ua),
            line: /Line\//.test(ua),
            wechat: /MicroMessenger/.test(ua),
            viber: /Viber/.test(ua),
            whatsapp: /WhatsApp/.test(ua),
            snapchat: /Snapchat/.test(ua)
        };

        for (let browser in isInAppBrowser) {
            if (isInAppBrowser[browser]) {
                return {
                    isInApp: true,
                    browserName: browser.charAt(0).toUpperCase() + browser.slice(1)
                };
            }
        }

        return { isInApp: false, browserName: null };
    }

    /**
     * Kung saan sila dapat pumunta, at paano makarating doon.
     *
     * Ang lumang teksto ay isang tagubilin para sa lahat — Android at
     * Chrome. Sa iPhone ay walang ⋮ sa itaas-kanan at walang Chrome:
     * ang estudyanteng sumusunod nang literal ay hindi makakahanap ng
     * anuman, at ang link ay hindi mabubuksan.
     */
    function platformGuide() {
        const ua = navigator.userAgent || '';

        if (/iPhone|iPad|iPod/i.test(ua)) {
            return {
                browser: 'Safari',
                steps: [
                    'Tap the <kbd>•••</kbd> or the compass icon at the corner of the screen',
                    'Choose <kbd>Open in Safari</kbd> or <kbd>Open in browser</kbd>'
                ]
            };
        }

        if (/Android/i.test(ua)) {
            return {
                browser: 'Chrome',
                steps: [
                    'Tap the <kbd>⋮</kbd> (three dots) at the top right',
                    'Choose <kbd>Open in Chrome</kbd> or <kbd>Open in browser</kbd>'
                ]
            };
        }

        return {
            browser: 'your browser',
            steps: [
                'Open the app’s menu (usually <kbd>⋮</kbd> or <kbd>•••</kbd>)',
                'Choose <kbd>Open in browser</kbd>'
            ]
        };
    }

    // ─── Clipboard ────────────────────────────────────────────
    function copyURL() {
        const url = window.location.href;

        if (navigator.clipboard && navigator.clipboard.writeText) {
            return navigator.clipboard.writeText(url).catch(() => fallbackCopy(url));
        }

        return Promise.resolve(fallbackCopy(url));
    }

    function fallbackCopy(url) {
        const textArea = document.createElement('textarea');
        textArea.value = url;
        textArea.style.position = 'fixed';
        textArea.style.opacity = '0';
        document.body.appendChild(textArea);
        textArea.select();

        try {
            document.execCommand('copy');
        } catch (e) {
            // Walang clipboard — nakikita pa rin nila ang URL sa address bar.
        }

        document.body.removeChild(textArea);
    }

    // Ibinabalik ang promise ng SweetAlert — nakasalalay dito ang
    // muling pagbukas ng babala kapag natapos ang timer.
    /**
     * Sinusubukang ilabas ang estudyante sa in-app browser.
     *
     * history.back() muna: sa Messenger o Instagram, ang nauna ay ang
     * mismong usapan o feed na pinanggalingan niya — kaya ito ang
     * pinakamalapit sa "isara mo na ito" na aktuwal na gumagana.
     *
     * window.close() ang pangalawa, na madalas ay walang epekto: ang
     * isang tab na hindi binuksan ng script ay hindi maisasara ng
     * script. Sinusubukan pa rin dahil may ilang webview na sumusunod.
     *
     * HINDI na kasama ang lumang ikatlong hakbang — ang pagpunta sa
     * about:blank kapag pareho silang nabigo. Iyon ay hindi pag-alis
     * kundi pagpunta sa isang blangkong pahina: nawawala ang tagubilin
     * at ang link, at wala nang mababalikan ang estudyante.
     */
    function leaveInAppBrowser() {
        if (window.history.length > 1) {
            window.history.back();
            return;
        }

        try {
            window.close();
        } catch (e) {
            // Inaasahan. Ang babala ang babalik kapag nandito pa rin siya.
        }
    }

    function showCopied(target) {
        return Swal.fire({
            icon: 'success',
            title: 'Link copied',
            text: 'Paste it into ' + target + ' to continue.',
            timer: 2600,
            showConfirmButton: false,
            allowOutsideClick: false,
            allowEscapeKey: false,
            customClass: { popup: 'det-popup' }
        });
    }

    // ─── Ang babala ───────────────────────────────────────────
    function showWarning(browserName) {
        if (typeof Swal === 'undefined') {
            // Walang SweetAlert sa pahinang ito. Isang plain na alert ay
            // pangit, pero mas mabuti kaysa sa tahimik na pagkabigo sa
            // isang browser na hindi kayang buksan ang camera.
            const g = platformGuide();
            alert('Please open this page in ' + g.browser + '.\n\nDetected: ' + browserName + ' in-app browser');
            return;
        }

        const guide = platformGuide();

        Swal.fire({
            icon: 'warning',
            title: 'Open in ' + guide.browser,
            html: `
                <div class="det-found">
                    <span class="det-dot"></span>
                    <span>Detected: <b>${browserName}</b> in-app browser</span>
                </div>

                <div class="det-steps">
                    <p class="det-steps-title">
                        <i class="bi bi-info-circle"></i> How to open it
                    </p>
                    <ol>
                        ${guide.steps.map(s => '<li>' + s + '</li>').join('')}
                    </ol>
                </div>

                <p class="det-note">
                    Scanning, uploading and downloading do not work reliably inside
                    ${browserName}. You can also copy the link and paste it into ${guide.browser}.
                </p>
            `,
            // Walang "Continue anyway", at walang paraang isara ito:
            // hindi gumagana ang camera at ang pag-upload sa loob ng
            // in-app browser, at hindi rin sumusunod ang layout sa
            // lapad ng telepono doon. Ang "makapagpatuloy" ay hindi
            // isang mas mababang antas ng serbisyo kundi isang sirang
            // pahina — kaya hindi ito inaalok bilang pagpipilian.
            confirmButtonText: 'Copy link',
            allowOutsideClick: false,
            allowEscapeKey: false,
            customClass: {
                popup: 'det-popup',
                title: 'det-title',
                confirmButton: 'det-confirm'
            },
            buttonsStyling: false
        }).then(result => {
            if (result.isConfirmed) {
                copyURL()
                    .then(() => showCopied(guide.browser))
                    .then(() => {
                        leaveInAppBrowser();

                        // Ang dalawang paraan ng pag-alis ay pareho
                        // TAHIMIK kapag nabigo — walang error at walang
                        // paraang tanungin kung tumalab ba. Kaya ganito
                        // ang pagkakaalam: kung talagang umalis ang
                        // pahina, hindi na tatakbo ang timer na ito
                        // dahil na-unload na ang dokumento. Kung
                        // tumakbo ito, ibig sabihin nandito pa rin siya
                        // — at kailangang bumalik ang babala, dahil
                        // kung hindi, ang "Copy link" ang magiging
                        // siya mismong "Continue anyway" na inalis:
                        // mananatiling bukas ang sirang pahina sa
                        // likod nito.
                        setTimeout(() => showWarning(browserName), 1200);
                    });
            }
        });
    }

    // ─── Public API (hindi nagbago) ───────────────────────────
    return {
        init: function () {
            if (window.__browserDetectorInitialized) return;
            window.__browserDetectorInitialized = true;

            const detection = detectInAppBrowser();
            if (detection.isInApp) {
                showWarning(detection.browserName);
            }
        },

        check: function () {
            return detectInAppBrowser();
        }
    };
})();

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
        BrowserDetector.init();
    });
} else {
    // DOM already loaded (script loaded after page load)
    BrowserDetector.init();
}
