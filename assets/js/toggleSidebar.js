// ============================================================
// SIDEBAR TOGGLE
//
// The button means different things depending on screen size:
//   desktop — shrink/expand (250px <-> 80px), as before
//   mobile  — slide out/in (off-canvas), because on a 390px screen
//             only 140px would be left for the content if the sidebar
//             stayed alongside.
//
// The 992px matches mobile.css's breakpoint.
// ============================================================

const SIDEBAR_MOBILE_QUERY = '(max-width: 992px)';

function isMobileLayout() {
    return window.matchMedia(SIDEBAR_MOBILE_QUERY).matches;
}

function getSidebarBackdrop() {
    let backdrop = document.getElementById('sidebarBackdrop');
    if (!backdrop) {
        // Done in JS so every page's markup does not have to change.
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

// Close the sidebar when a link is chosen — otherwise the overlay
// stays in the way while the new page loads.
document.addEventListener('click', function (e) {
    if (!isMobileLayout()) return;
    const link = e.target.closest('#sidebar .nav-link');
    // Dropdown toggles open a submenu rather than navigating — do not
    // close for those.
    if (link && !link.hasAttribute('data-bs-toggle')) {
        closeSidebarMobile();
    }
});

// Isara sa Escape.
document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && isMobileLayout()) closeSidebarMobile();
});

// When the phone is rotated or resized up to desktop, clear the
// mobile-only state so the overlay is not left stuck in place.
window.addEventListener('resize', function () {
    if (!isMobileLayout()) closeSidebarMobile();
});
