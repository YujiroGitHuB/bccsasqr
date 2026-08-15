/**
 * The QR module field on the login page's left plate.
 *
 * Drawn rather than written as 200 spans: the grid has to redraw at
 * the plate's real size on resize, and a finder pattern plus a
 * deterministic fill is a few lines of canvas against a wall of
 * markup that would also have to be hidden from screen readers one
 * element at a time.
 *
 * The plate keeps its slate ground in BOTH themes (see the note in
 * assets/css/login.css), so unlike the dashboard chart this canvas
 * does NOT need to repaint on `themechange` — its colours are the
 * same either way. It only follows the element's size.
 */

(function () {
    'use strict';

    var canvas = document.getElementById('plateModules');
    if (!canvas || !canvas.getContext) return;

    var ctx = canvas.getContext('2d');
    var host = canvas.parentElement;
    var GRID = 15;

    /* A deterministic hash, not Math.random: the pattern has to be
       the same after every resize, or the plate reshuffles itself
       while the window is being dragged. */
    function filled(x, y) {
        var h = (x * 73856093) ^ (y * 19349663);
        h = (h ^ (h >>> 13)) * 1274126177;
        return ((h ^ (h >>> 16)) >>> 0) % 100 < 42;
    }

    /* The three corners a real QR code reserves for its finder
       patterns are left empty, so the drawn one below has room. */
    function reserved(x, y) {
        return (x < 4 && y < 4) ||
            (x > GRID - 5 && y < 4) ||
            (x < 4 && y > GRID - 5);
    }

    function draw() {
        var w = host.clientWidth;
        var h = host.clientHeight;
        if (!w || !h) return;

        var dpr = window.devicePixelRatio || 1;
        canvas.width = w * dpr;
        canvas.height = h * dpr;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.clearRect(0, 0, w, h);

        var cell = Math.max(w, h) / GRID;
        var pad = cell * 0.14;
        var cols = Math.ceil(w / cell);
        var rows = Math.ceil(h / cell);

        for (var y = 0; y < rows; y++) {
            for (var x = 0; x < cols; x++) {
                if (reserved(x, y) || !filled(x, y)) continue;
                ctx.fillStyle = 'rgba(255, 255, 255, ' +
                    (0.05 + ((x + y) % 3) * 0.022) + ')';
                ctx.fillRect(x * cell + pad, y * cell + pad,
                    cell - pad * 2, cell - pad * 2);
            }
        }

        /* One finder pattern at true QR proportions. It is what makes
           the texture read as a QR code instead of noise, which is
           the point — the system's whole job is reading these. */
        var u = cell;
        ctx.strokeStyle = 'rgba(255, 255, 255, .16)';
        ctx.lineWidth = Math.max(1, u * 0.3);
        ctx.strokeRect(u * 0.65, u * 0.65, u * 2.7, u * 2.7);
        ctx.fillStyle = 'rgba(56, 189, 248, .28)';
        ctx.fillRect(u * 1.45, u * 1.45, u * 1.1, u * 1.1);
    }

    draw();

    /* ResizeObserver where it exists: the plate changes height when
       the form panel does (a validation message, the tabs), and a
       window resize listener never sees that. */
    if (window.ResizeObserver) {
        new ResizeObserver(draw).observe(host);
    } else {
        window.addEventListener('resize', draw);
    }
}());
