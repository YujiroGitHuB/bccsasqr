/**
 * Light / dark switch.
 *
 * The theme is already applied by the inline script in
 * includes/header.php — that has to happen before the first paint or
 * every page flashes the wrong colour. This file only handles the
 * toggle button and keeps the choice in step with the OS.
 *
 * Stored per browser in localStorage. With nothing stored the OS
 * setting wins, and keeps winning: the media-query listener below
 * follows it live, so switching the laptop to night mode changes the
 * app without a reload.
 */

(function () {
    'use strict';

    var KEY = 'bcc-theme';

    function stored() {
        try {
            var v = localStorage.getItem(KEY);
            return (v === 'light' || v === 'dark') ? v : null;
        } catch (e) {
            return null;
        }
    }

    function systemTheme() {
        return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }

    function current() {
        return document.documentElement.getAttribute('data-theme') || systemTheme();
    }

    function apply(theme) {
        var root = document.documentElement;
        root.setAttribute('data-theme', theme);
        // Bootstrap's own components read this one, not --data-theme.
        root.setAttribute('data-bs-theme', theme);
        paintButton(theme);
    }

    // The icon shows what you will GET, not what you are looking at:
    // in dark mode it offers the sun. A moon while already dark reads
    // as "you are in dark mode" and gets pressed by mistake.
    function paintButton(theme) {
        var btn = document.getElementById('themeToggle');
        if (!btn) return;

        var icon = btn.querySelector('i');
        var toLight = theme === 'dark';

        if (icon) icon.className = 'bi bi-' + (toLight ? 'sun-fill' : 'moon-stars-fill');
        btn.setAttribute('title', toLight ? 'Switch to light mode' : 'Switch to dark mode');
        btn.setAttribute('aria-label', btn.getAttribute('title'));
    }

    document.addEventListener('DOMContentLoaded', function () {
        paintButton(current());

        var btn = document.getElementById('themeToggle');
        if (btn) {
            btn.addEventListener('click', function () {
                var next = current() === 'dark' ? 'light' : 'dark';
                apply(next);
                try {
                    localStorage.setItem(KEY, next);
                } catch (e) {
                    // Private mode — the switch still works for this
                    // page load, it just will not be remembered.
                }
            });
        }
    });

    // Follow the OS, but only while the user has not chosen for
    // themselves. Once they have, their choice outranks the device.
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var onChange = function (e) {
        if (stored()) return;
        apply(e.matches ? 'dark' : 'light');
    };

    if (mq.addEventListener) mq.addEventListener('change', onChange);
    else if (mq.addListener) mq.addListener(onChange);   // older Safari
})();
