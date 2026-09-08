/**
 * "What's New" — the unread dot, and opening the timeline.
 *
 * The modal itself is server-rendered (components/whats_new_modal.php
 * from includes/whats_new.php); this only decides whether the browser
 * has already seen the newest release.
 *
 * WHERE THE "SEEN" MARK LIVES
 * In localStorage, per browser — not in the database. A column on
 * `users` would be the thorough answer, but it needs a migration on
 * a live database to announce a feature, and it still gets the same
 * question wrong in the other direction (one person, two browsers,
 * asked twice either way). If it ever needs to follow the account,
 * this is the one place that reads it.
 *
 * The version is not written here. It comes off the modal's
 * data-version attribute, which PHP fills from WHATS_NEW_VERSION, so
 * the marker cannot drift from the changelog.
 */

(function () {
    'use strict';

    var KEY = 'bcc-whats-new-seen';

    /* Open the timeline by itself the first time someone lands on a
       page after a release. A dot alone gets ignored for weeks; this
       is the only moment the announcement is actually worth
       something. Set to false to make the dot the only signal. */
    var AUTO_OPEN = true;

    function seen() {
        try {
            return localStorage.getItem(KEY);
        } catch (e) {
            // Private mode, or site data blocked. Treated as "seen":
            // an announcement that cannot be dismissed would open on
            // every single page load, which is worse than a missed one.
            return 'unavailable';
        }
    }

    function markSeen(version) {
        try {
            localStorage.setItem(KEY, version);
        } catch (e) {
            // Nothing to do — see above.
        }
    }

    document.addEventListener('DOMContentLoaded', function () {
        var modal = document.getElementById('whatsNewModal');
        var btn = document.getElementById('whatsNewBtn');
        if (!modal || !btn) return;

        var version = modal.getAttribute('data-version') || '';
        var unread = version !== '' && seen() !== version;

        // Bootstrap is loaded just above this file in
        // includes/footer.php. If a page ever loads one without the
        // other, the button should still not throw.
        var dialog = (window.bootstrap && window.bootstrap.Modal)
            ? window.bootstrap.Modal.getOrCreateInstance(modal)
            : null;

        if (unread) {
            btn.classList.add('is-unread');
            btn.setAttribute('title', 'New in this update');
            btn.setAttribute('aria-label', btn.getAttribute('title'));

            var dot = document.createElement('span');
            dot.className = 'tb-news-dot';
            btn.appendChild(dot);
        }

        // Opening it IS reading it — the dot goes on `shown`, not on
        // the click, so a dialog that failed to open leaves the mark
        // alone and tries again next time.
        modal.addEventListener('shown.bs.modal', function () {
            markSeen(version);
            btn.classList.remove('is-unread');
            btn.setAttribute('title', 'What\'s New');
            btn.setAttribute('aria-label', btn.getAttribute('title'));

            var dot = btn.querySelector('.tb-news-dot');
            if (dot) dot.remove();
        });

        btn.addEventListener('click', function () {
            if (dialog) dialog.show();
        });

        if (unread && AUTO_OPEN && dialog) {
            // A beat after paint. Opening a dialog into a page that is
            // still laying itself out puts it on top of a moving
            // target, and on a slow phone it can arrive before the
            // page does.
            setTimeout(function () {
                dialog.show();
            }, 900);
        }
    });
})();
