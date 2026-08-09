$(document).ready(function () {

    var systemName = "BCC Student Attendance System using QR";

    // ================================================================
    // ATTENDANCE TABLE (#example)
    // ================================================================
    if ($('#example').length) {
        $('#tableLoader').hide();
        $('#tableContainer').show();

        $('#example').DataTable({
            dom: 'Blfrtip',
            lengthMenu: [[5, 10, 25, 50, 100, -1], [5, 10, 25, 50, 100, "All"]],
            pageLength: 5,
            processing: true,
            language: {
                processing: '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>'
            },
            // Column 0 = checkbox, column 1 = running No.
            columnDefs: [
                { targets: 0, searchable: false, orderable: false, className: 'text-center' },
                { targets: 1, searchable: false, orderable: false }
            ],
            drawCallback: function (settings) {
                var api = this.api();
                var startIndex = api.context[0]._iDisplayStart;
                api.column(1, { page: 'current' }).nodes().each(function (cell, i) {
                    cell.innerHTML = startIndex + i + 1;
                });
            },
            buttons: [
                {
                    extend: 'copy', text: 'Copy Table', className: 'btn btn-sm btn-secondary',
                    title: function () { return systemName + ' - ' + ($('#filterSection').val() || 'All Sections'); },
                    exportOptions: { columns: ':not(:first-child):not(:last-child)', format: { body: function (data, row, column) { return column === 1 ? row + 1 : data; } } }
                },
                {
                    extend: 'csv', text: 'Export CSV', className: 'btn btn-sm btn-success',
                    title: function () { return systemName + ' - ' + ($('#filterSection').val() || 'All Sections'); },
                    exportOptions: { columns: ':not(:first-child):not(:last-child)', format: { body: function (data, row, column) { return column === 1 ? row + 1 : data; } } }
                },
                {
                    extend: 'excel', text: 'Export Excel', className: 'btn btn-sm btn-success',
                    title: function () { return systemName + ' - ' + ($('#filterSection').val() || 'All Sections'); },
                    exportOptions: { columns: ':not(:first-child):not(:last-child)', format: { body: function (data, row, column) { return column === 1 ? row + 1 : data; } } }
                },
                {
                    extend: 'pdf', text: 'Export PDF', className: 'btn btn-sm btn-danger',
                    title: function () { return systemName + ' - ' + ($('#filterSection').val() || 'All Sections'); },
                    exportOptions: { columns: ':not(:first-child):not(:last-child)', format: { body: function (data, row, column) { return column === 1 ? row + 1 : data; } } },
                    orientation: 'landscape',
                    customize: function (doc) {
                        doc.content.splice(0, 0, {
                            text: systemName + ' - ' + ($('#filterSection').val() || 'All Sections'),
                            fontSize: 14, bold: true, alignment: 'center', margin: [0, 0, 0, 10]
                        });
                    }
                },
                {
                    extend: 'print', text: 'Print Table', className: 'btn btn-sm btn-info',
                    title: function () { return systemName + ' - ' + ($('#filterSection').val() || 'All Sections'); },
                    exportOptions: { columns: ':not(:first-child):not(:last-child)', format: { body: function (data, row, column) { return column === 1 ? row + 1 : data; } } },
                    customize: function (win) {
                        $(win.document.body).prepend('<h3 style="text-align:center;">' + systemName + ' - ' + ($('#filterSection').val() || 'All Sections') + '</h3>');
                    }
                }
            ]
        });
    }

    // ================================================================
    // SUMMARY TAB (#summaryTable)
    // ================================================================
    var summaryTableInitialized = false;

    $('button[data-bs-toggle="tab"]').on('show.bs.tab', function (e) {
        var target = $(e.target).attr("data-bs-target");

        if (target === '#summary' && !summaryTableInitialized && $('#summaryTable').length) {
            $('#summaryTableLoader').hide();
            $('#summaryTableContainer').show();

            var summaryTable = $('#summaryTable').DataTable({
                dom: 'Blfrtip',
                lengthMenu: [[5, 10, 25, 50, 100, -1], [5, 10, 25, 50, 100, "All"]],
                pageLength: 5,
                processing: true,
                language: {
                    processing: '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>'
                },
                columnDefs: [{ targets: 0, searchable: false, orderable: false }],
                drawCallback: function (settings) {
                    var api = this.api();
                    var startIndex = api.context[0]._iDisplayStart;
                    api.column(0, { page: 'current' }).nodes().each(function (cell, i) {
                        cell.innerHTML = startIndex + i + 1;
                    });
                },
                buttons: [
                    { extend: 'copy',  text: 'Copy Table',   className: 'btn btn-sm btn-secondary', title: systemName + ' - Attendance Summary', exportOptions: { columns: ':visible' } },
                    { extend: 'csv',   text: 'Export CSV',   className: 'btn btn-sm btn-success',   title: systemName + ' - Attendance Summary', exportOptions: { columns: ':visible' } },
                    { extend: 'excel', text: 'Export Excel', className: 'btn btn-sm btn-success',   title: systemName + ' - Attendance Summary', exportOptions: { columns: ':visible' } },
                    { extend: 'pdf',   text: 'Export PDF',   className: 'btn btn-sm btn-danger',    title: systemName + ' - Attendance Summary', orientation: 'landscape', exportOptions: { columns: ':visible' } },
                    { extend: 'print', text: 'Print Table',  className: 'btn btn-sm btn-info',      title: systemName + ' - Attendance Summary', exportOptions: { columns: ':visible' } }
                ]
            });

            $('#filterSummaryCourse').on('change',  function () { summaryTable.column(3).search(this.value).draw(); });
            $('#filterSummarySection').on('change', function () { summaryTable.column(4).search(this.value).draw(); });
            $('#filterSummarySubject').on('change', function () { summaryTable.column(5).search(this.value).draw(); });
            $('#resetSummaryFilters').on('click', function () {
                $('#filterSummaryCourse, #filterSummarySection, #filterSummarySubject').val('');
                summaryTable.search('').columns().search('').draw();
            });

            summaryTableInitialized = true;
        }
    });

    // ================================================================
    // STUDENT TABLE (#stud_tbl)
    // ================================================================
    if ($('#stud_tbl').length) {
        $('#tableLoader').hide();
        $('#stud_tbl').show();

        $('#stud_tbl').DataTable({
            processing: true,
            language: {
                processing: '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>'
            },
            columnDefs: [
                { targets: 0, searchable: false, orderable: false, className: 'text-center' }, // checkbox
                { targets: 1, searchable: false, orderable: false }                            // No.
            ],
            drawCallback: function (settings) {
                var api = this.api();
                var startIndex = api.context[0]._iDisplayStart;
                api.column(1, { page: 'current' }).nodes().each(function (cell, i) {
                    cell.innerHTML = startIndex + i + 1;
                });
            },
            dom: '<"row"<"col-sm-12 col-md-6"l><"col-sm-12 col-md-6"f>>' +
                 '<"row"<"col-sm-12 col-md-6"B>>' +
                 '<"row"<"col-sm-12"tr>>' +
                 '<"row"<"col-sm-12 col-md-5"i><"col-sm-12 col-md-7"p>>',
            buttons: [
                { extend: 'copy',  text: '<i class="bi bi-clipboard"></i> Copy',          className: 'btn btn-sm btn-secondary', exportOptions: { columns: ':not(:first-child):not(:last-child)' } },
                { extend: 'csv',   text: '<i class="bi bi-file-earmark-csv"></i> CSV',     className: 'btn btn-sm btn-success',   exportOptions: { columns: ':not(:first-child):not(:last-child)' } },
                { extend: 'excel', text: '<i class="bi bi-file-earmark-excel"></i> Excel', className: 'btn btn-sm btn-success',   title: 'Students List', exportOptions: { columns: ':not(:first-child):not(:last-child)' } },
                { extend: 'pdf',   text: '<i class="bi bi-file-earmark-pdf"></i> PDF',     className: 'btn btn-sm btn-danger',    title: 'Students List', pageSize: 'LEGAL', exportOptions: { columns: ':not(:first-child):not(:last-child)' } },
                { extend: 'print', text: '<i class="bi bi-printer"></i> Print',            className: 'btn btn-sm btn-info',      title: 'Students List', exportOptions: { columns: ':not(:first-child):not(:last-child)' } }
            ],
            responsive: true,
            pageLength: 10,
            lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]]
        });
    }

    // ================================================================
    // OTHER TABLES
    // ================================================================
    if ($('#subjectTable').length)    { $('#subjectTable').DataTable(); }
    if ($('#assignmentTable').length) { $('#assignmentTable').DataTable(); }
    if ($('#usersTable').length)      { $('#usersTable').DataTable(); }

});