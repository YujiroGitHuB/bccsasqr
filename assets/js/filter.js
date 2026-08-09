$(document).ready(function () {
    // Only initialize if not already initialized (prevents "Cannot reinitialise DataTable")
    let table;
    if ($.fn.DataTable.isDataTable('#example')) {
        table = $('#example').DataTable();
    } else {
        table = $('#example').DataTable({
            pageLength: 10,
            order: [
                [0, 'desc']
            ],
            language: {
                search: "🔍 Search:",
                lengthMenu: "Show _MENU_ entries",
                info: "Showing _START_ to _END_ of _TOTAL_ records"
            }
        });
    }
    // Ang pag-filter ayon sa petsa ay nasa From/To na form ng attendance.php.
    // Server-side na iyon ngayon — hindi na lang itinatago ang rows, hindi na
    // talaga kinukuha sa database. Itakda ang From = To para sa isang araw.

    // Filter by Section (exact match)
    $('#filterSection').on('change', function () {
        const section = $(this).val();
        if (!section) {
            table.column(6).search('', true, false).draw();
            return;
        }
        // Exact match (case-insensitive handled by DataTables if server-side config allows,
        // otherwise we can use regex with case-insensitive flag if supported by your version)
        const regex = '^' + section.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$';
        table.column(6).search(regex, true, false).draw();
    });
    // Optional reset button (add a #resetFilters button in your HTML)
    // Nililinis lang nito ang mga filter sa loob ng naka-load na window.
    // Para baguhin ang window mismo, gamitin ang From/To o ang "Last 30 days".
    $('#resetFilters').on('click', function () {
        $('#filterSection').val('');
        table.search('').columns().search('').draw();
    });
});