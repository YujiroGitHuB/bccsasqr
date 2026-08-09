// ============================================================
// SIDEBAR TOGGLE
//
// Magkaibang kahulugan ang buton depende sa laki ng screen:
//   desktop — paliitin/palakihin (250px <-> 80px), gaya ng dati
//   mobile  — ilabas/ipasok (off-canvas), dahil sa 390px na screen
//             ay 140px na lang ang matitira sa content kung mananatili
//             ang sidebar sa tabi.
//
// Tugma ang 992px sa breakpoint ng mobile.css.
// ============================================================

const SIDEBAR_MOBILE_QUERY = '(max-width: 992px)';

function isMobileLayout() {
    return window.matchMedia(SIDEBAR_MOBILE_QUERY).matches;
}

function getSidebarBackdrop() {
    let backdrop = document.getElementById('sidebarBackdrop');
    if (!backdrop) {
        // Ginagawa sa JS para hindi na kailangang baguhin ang markup
        // ng bawat page.
        backdrop = document.createElement('button');
        backdrop.id = 'sidebarBackdrop';
        backdrop.className = 'sidebar-backdrop';
        backdrop.type = 'button';
        backdrop.setAttribute('aria-label', 'Close menu');
        backdrop.addEventListener('click', closeSidebarMobile);
        document.body.appendChild(backdrop);
    }
    return backdrop;
}

function closeSidebarMobile() {
    const sidebar = document.getElementById('sidebar');
    if (sidebar) sidebar.classList.remove('mobile-open');
    getSidebarBackdrop().classList.remove('show');
    document.body.classList.remove('sidebar-open');
}

function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    const content = document.getElementById('content');
    if (!sidebar) return;

    if (isMobileLayout()) {
        const open = sidebar.classList.toggle('mobile-open');
        getSidebarBackdrop().classList.toggle('show', open);
        document.body.classList.toggle('sidebar-open', open);
        return;
    }

    sidebar.classList.toggle('collapsed');
    if (content) content.classList.toggle('full');
}

// Kapag pumili ng link, isara ang sidebar — kung hindi, mananatiling
// nakaharang ang overlay habang naglo-load ang bagong page.
document.addEventListener('click', function (e) {
    if (!isMobileLayout()) return;
    const link = e.target.closest('#sidebar .nav-link');
    // Ang mga dropdown toggle ay nagbubukas ng submenu, hindi
    // naglilipat ng page — huwag isara para sa mga iyon.
    if (link && !link.hasAttribute('data-bs-toggle')) {
        closeSidebarMobile();
    }
});

// Isara sa Escape.
document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && isMobileLayout()) closeSidebarMobile();
});

// Kapag pinaikot ang telepono o nag-resize papuntang desktop, linisin
// ang mobile-only na estado para hindi maiwang nakasara ang overlay.
window.addEventListener('resize', function () {
    if (!isMobileLayout()) closeSidebarMobile();
});
