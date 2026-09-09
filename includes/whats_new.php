<?php
/*
 * ============================================================
 * "What's New" — the release timeline behind the topbar button.
 *
 * This file is the ONLY place the changelog is written. The modal
 * (components/whats_new_modal.php) renders whatever is here, so
 * announcing a feature is a matter of adding one entry — there is no
 * markup to touch.
 *
 * ── Adding a release ────────────────────────────────────────
 * Put the newest one FIRST (the array is rendered in order), then
 * RAISE WHATS_NEW_VERSION to match its `id`. The version is what
 * tells a browser it has not seen this release yet: the dot on the
 * topbar button comes back for everyone, once, and goes away again
 * when they open the modal. Leaving the version alone ships the
 * entry silently — which is the right thing for a typo fix.
 *
 * The same pattern as TERMS_VERSION in includes/terms.php.
 *
 * ── Why dates and not version numbers ───────────────────────
 * `system_acronym` in Settings already carries a released label
 * ("BCC SASQR v1.0"). Inventing a second, faster-moving numbering
 * here would put two different versions of the same system in front
 * of the same person. The releases are dated instead, and the ids
 * are those dates.
 *
 * ── Item types ──────────────────────────────────────────────
 *   'new'      — something that was not there before
 *   'improved' — something that was there and now works better
 *   'fixed'    — something that was broken
 * Anything else falls back to the neutral chip.
 *
 * `icon` is a Bootstrap Icons name (the same set the rest of the
 * admin uses); the release-level one sits in the timeline node.
 *
 * `text` is rendered as HTML so a phrase can be emphasised or a
 * path shown in <code>. It is written HERE, by whoever edits this
 * file — never from the database and never from a form — so there
 * is nothing user-supplied to escape.
 * ============================================================
 */

// Raise this to the newest release's `id` when you want the dot to
// come back for everyone. A release that is added to again on the same
// day takes a `.2`, `.3` suffix — the id stays the date, but the dot
// only returns when this string changes.
const WHATS_NEW_VERSION = '2026-09-09.3';

/**
 * The changelog, newest release first.
 *
 * @return array<int, array<string, mixed>>
 */
function whats_new_releases(): array
{
    return [

        [
            'id'      => '2026-09-09',
            'date'    => '2026-09-09',
            'icon'    => 'bi-shield-check',
            'title'   => 'Knowing whose phone it is',
            'summary' => 'Holding the attendance link and knowing a classmate\'s number used to be enough to sign them in. Five new checks close that, and a new page shows you every submission that was turned away.',
            'items'   => [
                [
                    'type'  => 'new',
                    'icon'  => 'bi-phone',
                    'title' => 'One device, one student',
                    'text'  => 'A phone that has recorded attendance for one student can no longer record it for a different student in the same class that day. This is the change that stops one person signing in the whole row &mdash; it is on by default, and there is a switch for it under <strong>Settings &rsaquo; Attendance rules</strong>.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-display',
                    'title' => 'A code on the board that changes every 30 seconds',
                    'text'  => 'Turn it on for a class from the <strong>Code</strong> button on its link card, and put the six digits on the projector. Students must type them to submit, so anyone who is not in the room cannot &mdash; by the time the code reaches the group chat, it has already changed.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-camera',
                    'title' => 'Selfie spot checks',
                    'text'  => 'A share of submissions &mdash; you choose the percentage &mdash; are asked for a quick photo before they are saved. Who gets asked is decided by the server and stays the same all day, so refreshing does not get anyone out of it. A phone that has submitted for three or more students in one week is always asked.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-shield-check',
                    'title' => 'A page showing what was turned away',
                    'text'  => '<strong>Attendance &rsaquo; Integrity</strong> lists every submission with the device and network it came from, flags each phone that was used for more than one student, and keeps the last 30 days.',
                ],
                [
                    'type'  => 'fixed',
                    'icon'  => 'bi-incognito',
                    'title' => 'The student lookup no longer answers to everyone',
                    'text'  => 'Typing a number on the attendance form returns a name, course, section and photo. That lookup did not check the link and was not rate limited, so it could be walked from <code>025-001</code> upward to read the whole school. It now requires a live attendance link, and counts how many numbers one device is asking about.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-person-square',
                    'title' => 'The tracker shows the student\'s photo',
                    'text'  => 'The result card carried only the two initials, so <em>A. Aquino</em> and <em>A. Abad</em> looked alike at a glance. It now shows the uploaded photo, and still falls back to the initials for anyone who has not uploaded one.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-palette',
                    'title' => 'The locked page follows your theme',
                    'text'  => 'It was dark-only, with its styling written into the page itself. It now uses the same tokens, card and buttons as everything else, and carries the floating theme switch — so it is light on a light system and dark on a dark one.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-signpost-2',
                    'title' => 'It says which page is locked, and offers a way back',
                    'text'  => 'The heading now names the page you were trying to reach — <em>QR Generator</em>, <em>QR Scanner</em>, <em>Attendance Tracker</em> or <em>Registration</em> — and a <strong>Check again</strong> button lets a visitor find out that the lock has lifted without retyping the address.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-hand-index',
                    'title' => 'One clear way to reach the developer',
                    'text'  => 'Facebook and Messenger were two identical blue buttons competing for the same click. Messenger leads now, Facebook sits beside it as an outline, and the bouncing padlock emoji — drawn by the phone, so it was orange on every Android — is a proper icon.',
                ],
                [
                    'type'  => 'fixed',
                    'icon'  => 'bi-image',
                    'title' => 'The school logo shows on the locked registration page',
                    'text'  => 'The page assumed it was always one folder deep, so on <code>reg.php</code> the logo pointed above the site root and the browser tab came up blank.',
                ],
            ],
        ],

        [
            'id'      => '2026-09-08',
            'date'    => '2026-09-08',
            'icon'    => 'bi-lightning-charge-fill',
            'title'   => 'Pages that keep up with you',
            'summary' => 'The heaviest page in the system was doing all of its work before showing you anything, and the scanner was redoing all of its work on every single camera frame.',
            'items'   => [
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-stopwatch',
                    'title' => 'A much lighter Subject Enrollment page',
                    'text'  => 'It used to write out all 1,586 enrollments and every student in the school — about 4.4&nbsp;MB — before the first five rows could appear. The rows now arrive as they are needed, which is roughly a thirteenth of that.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-search',
                    'title' => 'A student picker that keeps up with typing',
                    'text'  => 'The dropdown draws only the names your search actually matches instead of all 1,500 at once, so it no longer stutters on each keystroke.',
                ],
                [
                    'type'  => 'fixed',
                    'icon'  => 'bi-quote',
                    'title' => 'Names with an apostrophe',
                    'text'  => 'The remove button on an enrollment broke on a name like O&rsquo;Brien. It does not any more.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-camera-video',
                    'title' => 'A scanner that keeps up with back-to-back scans',
                    'text'  => 'Every frame from the camera was being read at its full size, sixty times a second, which is what made the picture stutter and each scan land a beat late. It now reads a smaller frame about twelve times a second &mdash; more than enough for a QR code. The beep also went silent on the second scan of a queue; it sounds every time now.',
                ],
                [
                    'type'  => 'fixed',
                    'icon'  => 'bi-volume-up',
                    'title' => 'Student names are spoken, not spelled out',
                    'text'  => 'Names arrive from the school&rsquo;s export in capitals, and every voice reads a word in capitals letter by letter &mdash; so <code>DELA CRUZ, JUAN P.</code> was being spelled aloud. The scanner now says &ldquo;Juan Dela Cruz&rdquo;, and it no longer runs so long that the next scan cuts it off mid-name.',
                ],
                [
                    'type'  => 'fixed',
                    'icon'  => 'bi-window-stack',
                    'title' => 'The dashboard no longer appears inside itself',
                    'text'  => 'After half a minute, the Recent Activity panel refreshed itself with a whole second copy of the dashboard &mdash; topbar, cards and all &mdash; instead of the five scan rows. It asks for the rows correctly now, and it will only ever draw rows, so an expired sign-in cannot put a login page in there either.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-stars',
                    'title' => 'This page',
                    'text'  => 'The What&rsquo;s New button in the topbar, and the timeline you are reading. The dot returns whenever there is something new to say.',
                ],
            ],
        ],

        [
            'id'      => '2026-09-07',
            'date'    => '2026-09-07',
            'icon'    => 'bi-plug-fill',
            'title'   => 'An API other apps can talk to',
            'summary' => 'The system is no longer only a website — other tools can read from it without being handed the database.',
            'items'   => [
                [
                    'type'  => 'new',
                    'icon'  => 'bi-braces',
                    'title' => 'Versioned REST API',
                    'text'  => 'A stable <code>api/v1</code> endpoint serves student lookups, terms status and system details as JSON. Being versioned means a later change cannot break whatever is already using it.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-speedometer',
                    'title' => 'Request throttling',
                    'text'  => 'Repeated calls from the same address are rate limited, so an API client stuck in a loop cannot bury the database the admin pages share.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-18',
            'date'    => '2026-08-18',
            'icon'    => 'bi-file-earmark-pdf-fill',
            'title'   => 'Lighter pages, better reports',
            'summary' => 'A round of weight taken off the admin pages, and a report that used to be assembled by hand.',
            'items'   => [
                [
                    'type'  => 'new',
                    'icon'  => 'bi-filetype-pdf',
                    'title' => 'Attendance summary as a PDF',
                    'text'  => 'The summary exports straight to a printable PDF, carrying the report header set in Settings.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-lightning-charge-fill',
                    'title' => 'Faster tables',
                    'text'  => 'The unused Copy/CSV/Excel/Print bar and its export libraries were removed from every table, so each admin page now downloads noticeably less to show the same data.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-signpost-2-fill',
                    'title' => 'Errors that explain themselves',
                    'text'  => 'A wrong link or an expired session lands on a page that says what happened and where to go next, instead of a blank screen.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-17',
            'date'    => '2026-08-17',
            'icon'    => 'bi-calendar2-check-fill',
            'title'   => 'Attendance at a glance',
            'summary' => 'The day view is the page people spend the most time on, and the least had been done to it.',
            'items'   => [
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-window-stack',
                    'title' => 'Redesigned attendance view',
                    'text'  => 'A day&rsquo;s record opens in the house modal style — the counts up top, the roster below, and it stays readable on a phone.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-person-badge-fill',
                    'title' => 'Photo required before verifying',
                    'text'  => 'With the requirement switched on, a student with no profile photo is stopped at verification instead of being quietly marked present.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-16',
            'date'    => '2026-08-16',
            'icon'    => 'bi-person-bounding-box',
            'title'   => 'Face sign-in, tightened',
            'summary' => 'Signing in with a face was already there; this is what made it trustworthy enough to leave on.',
            'items'   => [
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-camera-fill',
                    'title' => 'Steadier face login',
                    'text'  => 'The camera step recovers from a refused or already-busy camera instead of hanging, and says which of the two happened.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-fingerprint',
                    'title' => 'Duplicate face check',
                    'text'  => 'A face already enrolled to another account is refused at registration, so one face cannot open two accounts.',
                ],
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-person-circle',
                    'title' => 'Your photo, everywhere',
                    'text'  => 'The picture set on a profile now shows in the topbar and the account menu, not only on the profile page.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-15',
            'date'    => '2026-08-15',
            'icon'    => 'bi-link-45deg',
            'title'   => 'Attendance links that expire',
            'summary' => 'A shared attendance link used to work forever, which made it worth passing around.',
            'items'   => [
                [
                    'type'  => 'new',
                    'icon'  => 'bi-hourglass-split',
                    'title' => 'Expiry on every link',
                    'text'  => 'A generated link can be given a cut-off. Past it the page refuses the scan rather than recording it.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-arrow-repeat',
                    'title' => 'Regenerate a code',
                    'text'  => 'A link that has travelled too far can be reissued with a new code, which retires the old one immediately.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-activity',
                    'title' => 'Recent activity on the dashboard',
                    'text'  => 'The latest scans appear on the dashboard as they arrive, so a session can be watched without opening the attendance page.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-13',
            'date'    => '2026-08-13',
            'icon'    => 'bi-shield-lock-fill',
            'title'   => 'Permissions per person',
            'summary' => 'Roles were all or nothing: an instructor either saw everything an admin saw, or could not be given anything extra.',
            'items'   => [
                [
                    'type'  => 'new',
                    'icon'  => 'bi-toggles',
                    'title' => 'Granular user permissions',
                    'text'  => 'Access is granted feature by feature — managing students, locking attendance, reaching Settings — from the user management page. Menus and buttons a person cannot use are no longer shown to them.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-12',
            'date'    => '2026-08-12',
            'icon'    => 'bi-sun-fill',
            'title'   => 'Light mode, and reports with your name on them',
            'summary' => 'The system had been dark-only since it was built. It now follows the device, or whichever you pick.',
            'items'   => [
                [
                    'type'  => 'new',
                    'icon'  => 'bi-circle-half',
                    'title' => 'Light and dark theme',
                    'text'  => 'Every page, modal and dialog has a light version. It starts from the device setting, the switch in the topbar overrides it, and the choice is remembered.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-file-earmark-text-fill',
                    'title' => 'Custom report header and footer',
                    'text'  => 'The school name, the office line and the developer credit on printed reports and at the foot of the site are set in Settings instead of edited in code.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-arrow-up-right-circle-fill',
                    'title' => 'Section promotion',
                    'text'  => 'A whole section moves up a year level in one action at the end of a term.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-10',
            'date'    => '2026-08-10',
            'icon'    => 'bi-clipboard2-check-fill',
            'title'   => 'Consent and identity',
            'summary' => 'The QR code identifies a real student, so what it does had to be said out loud — and the record had to carry a face.',
            'items'   => [
                [
                    'type'  => 'new',
                    'icon'  => 'bi-file-earmark-lock-fill',
                    'title' => 'Terms before a QR is generated',
                    'text'  => 'A student reads and accepts the terms once before their first QR code. Acceptances are kept with their date, and raising the terms version asks everyone again.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-camera2',
                    'title' => 'Optional student photo requirement',
                    'text'  => 'Settings can require a profile photo on every student record, so a scan can be matched against a face.',
                ],
                [
                    'type'  => 'new',
                    'icon'  => 'bi-person-square',
                    'title' => 'Account avatars',
                    'text'  => 'Staff accounts can carry a photo, shown in the topbar in place of the generic icon.',
                ],
            ],
        ],

        [
            'id'      => '2026-08-09',
            'date'    => '2026-08-09',
            'icon'    => 'bi-database-fill-check',
            'title'   => 'Groundwork',
            'summary' => 'Nothing visible — the lookups everything else is built on stopped reading the whole table.',
            'items'   => [
                [
                    'type'  => 'improved',
                    'icon'  => 'bi-search',
                    'title' => 'Indexed student and date lookups',
                    'text'  => 'Student number and attendance date are indexed. Scanning, the day view and the reports all read through those, and all got faster as the records piled up.',
                ],
            ],
        ],

    ];
}

/**
 * The chip shown against an item. Returns the label and the modifier
 * class; an unknown type comes back neutral rather than unstyled, so
 * a typo in the array above cannot produce an invisible label.
 *
 * @return array{0:string, 1:string}
 */
function whats_new_tag(string $type): array
{
    switch ($type) {
        case 'new':
            return ['New', 'is-new'];
        case 'improved':
            return ['Improved', 'is-improved'];
        case 'fixed':
            return ['Fixed', 'is-fixed'];
        default:
            return [ucfirst($type), 'is-plain'];
    }
}

// No closing PHP tag on purpose — see includes/systemConfig.php.
