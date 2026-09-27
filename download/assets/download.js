/* ============================================================
   DOWNLOAD PAGE — the moving parts.

   Five small jobs, each optional: the page reads fine if any of
   them fails or never runs.

   1. The hand-off QR — this page's own address, for a visitor on a
      computer to scan with their phone.
   2. The scene's tilt — follows the mouse on a computer, the phone's
      own tilt on Android.
   3. The cards' tilt — a small lean toward the pointer.
   4. The scroll reveal.
   5. The three screens — swiped, dragged, or picked with the arrows
      and pills; turning on their own until the visitor takes over.

   Every motion is skipped when the visitor has asked their system
   for reduced motion.
   ============================================================ */

(function () {
    'use strict';

    var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var finePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches;

    function clamp(value, min, max) {
        return Math.min(max, Math.max(min, value));
    }

    // ─── 1. Hand-off QR ───────────────────────────────────────
    (function handoff() {
        var el = document.getElementById('handoffCode');
        if (!el) return;

        // The CDN can be blocked on a school network. Without a code
        // there is nothing to scan, so the whole box goes.
        if (typeof QRCode === 'undefined') {
            el.parentElement.style.display = 'none';
            return;
        }

        new QRCode(el, {
            text: location.href.split('#')[0],
            width: 184,
            height: 184,
            // Dark on white, on purpose: see .dl-handoff-code.
            colorDark: '#0f172a',
            colorLight: '#ffffff',
            correctLevel: QRCode.CorrectLevel.M
        });
    })();

    // ─── 2. Scene tilt ────────────────────────────────────────
    (function sceneTilt() {
        var scene = document.getElementById('scene');
        if (!scene || reduceMotion) return;

        var frame = 0;
        function set(rx, ry) {
            cancelAnimationFrame(frame);
            frame = requestAnimationFrame(function () {
                scene.style.setProperty('--rx', rx.toFixed(2) + 'deg');
                scene.style.setProperty('--ry', ry.toFixed(2) + 'deg');
            });
        }

        if (finePointer) {
            var hero = document.querySelector('.dl-hero');
            hero.addEventListener('pointermove', function (e) {
                var box = hero.getBoundingClientRect();
                var x = (e.clientX - box.left) / box.width - 0.5;
                var y = (e.clientY - box.top) / box.height - 0.5;
                set(-y * 10, x * 16);
            });
            hero.addEventListener('pointerleave', function () {
                set(0, 0);
            });
            return;
        }

        // Android hands out orientation freely. iOS wants a permission
        // prompt for it — not worth a dialog for a decoration, so an
        // iPhone simply sees the scene still.
        if (typeof DeviceOrientationEvent === 'undefined' ||
            typeof DeviceOrientationEvent.requestPermission === 'function') {
            return;
        }

        // Relative to how the phone was held when the page opened, so
        // a phone held upright is not read as tilted all the way back.
        var baseBeta = null;
        window.addEventListener('deviceorientation', function (e) {
            if (e.beta === null || e.gamma === null) return;
            if (baseBeta === null) baseBeta = e.beta;
            set(clamp(-(e.beta - baseBeta) / 3, -8, 8), clamp(e.gamma / 3, -12, 12));
        });
    })();

    // ─── 3. Card tilt ─────────────────────────────────────────
    (function cardTilt() {
        if (!finePointer || reduceMotion) return;

        document.querySelectorAll('.dl-card').forEach(function (card) {
            card.addEventListener('pointermove', function (e) {
                var box = card.getBoundingClientRect();
                var x = (e.clientX - box.left) / box.width - 0.5;
                var y = (e.clientY - box.top) / box.height - 0.5;
                card.style.setProperty('--card-rx', (-y * 6).toFixed(2) + 'deg');
                card.style.setProperty('--card-ry', (x * 8).toFixed(2) + 'deg');
            });
            card.addEventListener('pointerleave', function () {
                card.style.setProperty('--card-rx', '0deg');
                card.style.setProperty('--card-ry', '0deg');
            });
        });
    })();

    // ─── 4. Scroll reveal ─────────────────────────────────────
    (function reveal() {
        var items = document.querySelectorAll('.dl-reveal');

        if (reduceMotion || !('IntersectionObserver' in window)) {
            items.forEach(function (el) { el.classList.add('is-in'); });
            return;
        }

        var seen = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                var el = entry.target;
                el.classList.add('is-in');
                seen.unobserve(el);
                // The delay would also hold back the hover tilt; it is
                // only for the entrance.
                setTimeout(function () { el.style.transitionDelay = ''; }, 900);
            });
        }, { rootMargin: '0px 0px -8% 0px' });

        // A small stagger inside each row, so a grid of cards arrives
        // one after another rather than as a single slab.
        items.forEach(function (el) {
            var siblings = Array.prototype.indexOf.call(el.parentElement.children, el);
            el.style.transitionDelay = (siblings % 4) * 70 + 'ms';
            seen.observe(el);
        });
    })();
    // ─── 5. The three screens ─────────────────────────────────
    (function screens() {
        var scene = document.getElementById('scene');
        var stage = scene && scene.closest('.dl-stage');
        if (!stage) return;

        var phones = Array.prototype.slice.call(scene.querySelectorAll('.dl-phone'));
        var pills = Array.prototype.slice.call(stage.querySelectorAll('.dl-pill'));
        var count = phones.length;
        var active = 0;

        // The one in front gets is-active, the next one round is-next,
        // the one before is-prev — so every turn is a single step either
        // way, whichever screen it starts from.
        function show(index) {
            active = (index % count + count) % count;
            phones.forEach(function (phone) {
                var step = (Number(phone.getAttribute('data-screen')) - active + count) % count;
                phone.classList.toggle('is-active', step === 0);
                phone.classList.toggle('is-next', step === 1);
                phone.classList.toggle('is-prev', step === count - 1);
            });
            pills.forEach(function (pill) {
                pill.setAttribute('aria-pressed', String(Number(pill.getAttribute('data-go')) === active));
            });
            scene.setAttribute('data-active', String(active));
        }

        // Turning on its own shows at a glance that there is more than
        // one screen — until the visitor touches anything, after which
        // it is theirs to turn. Never with reduced motion.
        var auto = null;
        var hovering = false;
        function stopAuto() {
            clearInterval(auto);
            auto = null;
        }
        if (!reduceMotion) {
            auto = setInterval(function () {
                if (!hovering && !document.hidden) show(active + 1);
            }, 4500);
            stage.addEventListener('mouseenter', function () { hovering = true; });
            stage.addEventListener('mouseleave', function () { hovering = false; });
        }

        stage.querySelectorAll('[data-step]').forEach(function (button) {
            button.addEventListener('click', function () {
                stopAuto();
                show(active + Number(button.getAttribute('data-step')));
            });
        });

        pills.forEach(function (pill) {
            pill.addEventListener('click', function () {
                stopAuto();
                show(Number(pill.getAttribute('data-go')));
            });
        });

        // Left and right arrow keys from any of the controls.
        var controls = stage.querySelector('.dl-switch');
        if (controls) {
            controls.addEventListener('keydown', function (e) {
                if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
                e.preventDefault();
                stopAuto();
                show(active + (e.key === 'ArrowRight' ? 1 : -1));
                if (pills[active]) pills[active].focus();
            });
        }

        // A swipe on a phone, a drag with the mouse. The scene leans with
        // the finger while it moves; far enough sideways and it turns.
        // A tap on one of the phones behind brings that one to the front.
        var start = null;
        function reset() {
            start = null;
            scene.classList.remove('is-dragging');
            scene.style.setProperty('--drag', '0deg');
        }

        scene.addEventListener('pointerdown', function (e) {
            if (e.pointerType === 'mouse' && e.button !== 0) return;
            start = { x: e.clientX, y: e.clientY, id: e.pointerId };
            stopAuto();
        });

        window.addEventListener('pointermove', function (e) {
            if (!start || e.pointerId !== start.id) return;
            var dx = e.clientX - start.x;
            if (Math.abs(dx) < 6) return;
            scene.classList.add('is-dragging');
            if (!reduceMotion) {
                scene.style.setProperty('--drag', clamp(dx / 7, -16, 16).toFixed(1) + 'deg');
            }
        });

        window.addEventListener('pointerup', function (e) {
            if (!start || e.pointerId !== start.id) return;
            var dx = e.clientX - start.x;
            var dy = e.clientY - start.y;
            var target = e.target instanceof Element ? e.target.closest('.dl-phone') : null;
            reset();

            if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) {
                show(active + (dx < 0 ? 1 : -1));
            } else if (Math.abs(dx) < 8 && Math.abs(dy) < 8 && target && !target.classList.contains('is-active')) {
                show(Number(target.getAttribute('data-screen')));
            }
        });

        // The page scrolled instead: the browser took the gesture.
        window.addEventListener('pointercancel', reset);

        show(0);
    })();
})();
