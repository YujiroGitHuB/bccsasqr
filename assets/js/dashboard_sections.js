/**
 * Dashboard — search and sort for the section cards.
 *
 * An instructor with four sections does not need this; an admin with
 * twenty-six was scrolling a wall of cards to find one, and had no way
 * to ask the question the cards exist to answer ("which section is
 * doing worst?") without reading every one.
 *
 * Client-side on purpose: every card is already in the document, and a
 * round trip to reorder what is in front of you is the slower answer.
 * The toolbar reveals itself from JavaScript (it ships `hidden`), so a
 * browser that cannot run this never shows a control that does nothing.
 *
 * The cards are grouped under year headings. Sorting by anything other
 * than the default breaks those groups — a list ordered by engagement
 * that still claims to be "1st Year" would be lying — so the headings
 * are hidden for as long as another sort is active.
 */

(function () {
    'use strict';

    document.addEventListener('DOMContentLoaded', function () {
        var grid = document.getElementById('sectionCards');
        var bar = document.getElementById('sectionToolbar');
        if (!grid || !bar) return;

        var search = document.getElementById('sectionSearch');
        var sort = document.getElementById('sectionSort');
        var count = document.getElementById('sectionCount');

        var cards = Array.prototype.slice.call(grid.querySelectorAll('.dash-card-col'));
        var heads = Array.prototype.slice.call(grid.querySelectorAll('[data-year-header]'));
        if (cards.length < 2) return;   // nothing to search or sort

        // The document order is the default order; keeping a copy means
        // "Year & name" can be restored without a reload.
        var original = Array.prototype.slice.call(grid.children);

        bar.hidden = false;

        function num(el, name) {
            return parseFloat(el.getAttribute(name)) || 0;
        }

        var comparators = {
            engagement: function (a, b) { return num(a, 'data-engagement') - num(b, 'data-engagement'); },
            risk: function (a, b) { return num(b, 'data-risk') - num(a, 'data-risk'); },
            students: function (a, b) { return num(b, 'data-students') - num(a, 'data-students'); }
        };

        function apply() {
            var term = (search.value || '').trim().toLowerCase();
            var mode = sort.value;
            var grouped = (mode === 'default');
            var shown = 0;

            // ── Filter ──
            cards.forEach(function (card) {
                var name = (card.getAttribute('data-section') || '').toLowerCase();
                var year = (card.getAttribute('data-year') || '').toLowerCase();
                var hit = !term || name.indexOf(term) !== -1 || year.indexOf(term) !== -1;

                card.hidden = !hit;
                if (hit) shown++;
            });

            // ── Order ──
            // One fragment, one reflow, rather than one per card.
            var frag = document.createDocumentFragment();

            if (grouped) {
                original.forEach(function (node) { frag.appendChild(node); });
            } else {
                cards.slice().sort(comparators[mode]).forEach(function (card) {
                    frag.appendChild(card);
                });
            }
            grid.appendChild(frag);

            // ── Year headings ──
            heads.forEach(function (head) {
                if (!grouped) {
                    head.hidden = true;
                    return;
                }
                // A heading with nothing left under it is noise.
                var year = head.getAttribute('data-year-header');
                head.hidden = !cards.some(function (card) {
                    return !card.hidden && card.getAttribute('data-year') === year;
                });
            });

            // ── Count ──
            if (count) {
                if (term) {
                    count.textContent = shown + ' of ' + cards.length + ' sections';
                } else {
                    count.textContent = cards.length + ' section' + (cards.length === 1 ? '' : 's');
                }
            }
        }

        // `input` rather than `keyup`: it also catches paste and the
        // browser's own clear button on a search field.
        search.addEventListener('input', apply);
        sort.addEventListener('change', apply);

        // Escape clears the box, which is what a search field is
        // expected to do and saves reaching for the mouse.
        search.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && search.value) {
                search.value = '';
                apply();
            }
        });

        apply();
    });
})();
