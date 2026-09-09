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
    //
    // Sa SERVER na ito ginagawa ngayon. Dati ay isang regex search sa
    // hanay 6, na gumagana lamang habang hawak ng browser ang lahat ng
    // hilera — hindi masasala ng DataTables ang hindi naman nito
    // hawak. Ang halaga ay ipinapasa ng assets/js/datatables.js sa
    // bawat request (ang `d.section`), kaya ang kailangan lamang dito
    // ay ang muling pagtatanong.
    //
    // ajax.reload(null, false): ang `false` ay nagpapanatili ng
    // kasalukuyang pahina. Sa isang PAGSASALA ay dapat itong bumalik
    // sa una — ang pahina 8 ng isang bagong, mas maikling listahan ay
    // madalas na wala nang laman — kaya `true` ang ipinapasa rito.
    $('#filterSection').on('change', function () {
        table.ajax.reload(null, true);
    });

    // Optional reset button (add a #resetFilters button in your HTML)
    // This only clears the filters within the loaded window. To change
    // the window itself, use From/To or "Last 30 days".
    $('#resetFilters').on('click', function () {
        $('#filterSection').val('');
        // Isang draw lamang, hindi dalawa: ang .search('') ay
        // nagtatakda nang hindi nagtatanong, at ang reload ang
        // nagdadala ng pareho sa server nang sabay.
        table.search('');
        table.ajax.reload(null, true);
    });

    // Ang section ay maaaring naka-preselect na mula sa isang link
    // (ang mga section card ng dashboard ay tumuturo rito na may
    // ?section=2A).
    //
    // WALA nang ginagawa rito ngayon, at sinasadya: ang `data` callback
    // sa assets/js/datatables.js ay binabasa ang halaga ng dropdown sa
    // BAWAT request, kasama ang pinakauna — kaya nakasala na ito bago
    // pa may makita. Noong nasa browser ang pagsasala, kailangan ng
    // manwal na `change` dito dahil sa `change` lamang tumatakbo ang
    // filter; ang pag-uulit niyon ngayon ay pangalawang tanong sa
    // server para sa eksaktong parehong sagot.
});