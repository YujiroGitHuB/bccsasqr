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
    // Filtering by date lives in attendance.php's From/To form. That is
    // server-side now — the rows are not merely hidden, they are never
    // fetched from the database. Set From = To for a single day.

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
    // This only clears the filters within the loaded window. To change
    // the window itself, use From/To or "Last 30 days".
    $('#resetFilters').on('click', function () {
        $('#filterSection').val('');
        table.search('').columns().search('').draw();
    });
});