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
    $('#filterDate').on('change', function () {
        const date = $(this).val(); // YYYY-MM-DD or ""
        if (!date) {
            // clear date filter only (leave other column filters intact)
            table.column(2).search('', true, false).draw();
            return;
        }
        // Use regex to match the date anywhere in the cell (disable smart search)
        const regex = date.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&'); // escape special chars just in case
        table.column(2).search(regex, true, false).draw();
    });
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
    $('#resetFilters').on('click', function () {
        $('#filterDate').val('');
        $('#filterSection').val('');
        table.search('').columns().search('').draw();
    });
});