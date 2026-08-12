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
            // Once only — fetch the summary when the tab is opened.
            // It used to ship inside the HTML on every page load.
            summaryTableInitialized = true;
            $('#summaryTableLoader').show();

            fetch('get_summary_ajax.php')
                .then(function (r) { return r.json(); })
                .then(function (res) {
                    $('#summaryTableLoader').hide();

                    if (!res.success) {
                        summaryTableInitialized = false;
                        $('#summaryTableEmpty')
                            .text(res.message || 'Could not load the summary. Please try again.')
                            .show();
                        return;
                    }
                    if (!res.data.length) {
                        $('#summaryTableEmpty').show();
                        return;
                    }

                    buildSummaryFilters(res.filters);
                    $('#summaryTableContainer').show();
                    initSummaryTable(res.data);
                })
                .catch(function () {
                    // Payagang subukan muli sa susunod na pag-click ng tab.
                    summaryTableInitialized = false;
                    $('#summaryTableLoader').hide();
                    $('#summaryTableEmpty')
                        .text('Could not load the summary. Please try again.')
                        .show();
                });
        }
    });

    function buildSummaryFilters(filters) {
        var fill = function (sel, values) {
            var $s = $(sel);
            values.forEach(function (v) {
                $s.append($('<option>').attr('value', v).text(v));
            });
        };
        fill('#filterSummaryCourse',  filters.courses);
        fill('#filterSummarySection', filters.sections);
        fill('#filterSummarySubject', filters.subjects);
    }

    function initSummaryTable(rows) {
        var esc = $.fn.dataTable.render.text();

        var summaryTable = $('#summaryTable').DataTable({
            data: rows,
            columns: [
                { data: null, defaultContent: '' },   // running No., punan ng drawCallback
                { data: 'student_no',       render: esc },
                { data: 'fullname',         render: esc },
                { data: 'course',           render: esc },
                { data: 'section',          render: esc },
                { data: 'subject',          render: esc },
                { data: 'total_attendance', render: esc }
            ],
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
    }

    // ================================================================
    // STUDENT TABLE (#stud_tbl)
    // ================================================================
    if ($('#stud_tbl').length) {
        // The rows arrive as JSON from get_students_ajax.php — about
        // 74% lighter than HTML, and DataTables only builds the DOM
        // for the current page.
        var escText = $.fn.dataTable.render.text();

        // For markup built here by hand (the checkbox and buttons) the
        // value has to be escaped before it goes into an attribute.
        var attr = function (v) {
            return String(v === null || v === undefined ? '' : v)
                .replace(/&/g, '&amp;').replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        };

        $('#stud_tbl').DataTable({
            ajax: {
                url: 'get_students_ajax.php',
                dataSrc: function (res) {
                    $('#tableLoader').hide();
                    $('#stud_tbl').show();
                    if (!res.success) {
                        Swal.fire({
                            icon: 'error', title: 'Error!',
                            background: '#0f172a', color: '#e0e0e0',
                            text: res.message || 'Could not load the student list.'
                        });
                        return [];
                    }
                    return res.data;
                }
            },
            columns: [
                {
                    data: 'id',
                    render: function (id) {
                        return '<input type="checkbox" class="form-check-input row-checkbox" value="' + attr(id) + '">';
                    }
                },
                { data: null, defaultContent: '' },      // running No., punan ng drawCallback
                { data: 'student_no', render: escText },
                { data: 'fullname',   render: escText },
                { data: 'course',     render: escText },
                { data: 'section',    render: escText },
                { data: 'added_by',   render: escText },
                {
                    data: null,
                    render: function (row) {
                        // data-* attributes instead of an inline onclick: an
                        // apostrophe in a name cannot break it, and it does
                        // not rely on PHP escaping inside a JS string.
                        return '<button class="btn btn-sm btn-success me-2 btn-edit-student"' +
                               ' data-id="'      + attr(row.id) + '"' +
                               ' data-no="'      + attr(row.student_no) + '"' +
                               ' data-fullname="' + attr(row.fullname) + '"' +
                               ' data-course="'  + attr(row.course) + '"' +
                               ' data-section="' + attr(row.section) + '">' +
                               '<i class="bi bi-pencil-square"></i></button>' +
                               '<button class="btn btn-sm btn-danger btn-deletes" data-id="' + attr(row.id) + '">' +
                               '<i class="bi bi-trash"></i></button>';
                    }
                }
            ],
            createdRow: function (tr, data) {
                // delete and deleteSelected both rely on this id.
                tr.id = 'row-' + data.id;
            },
            processing: true,
            language: {
                processing: '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>'
            },
            columnDefs: [
                { targets: 0, searchable: false, orderable: false, className: 'text-center' }, // checkbox
                { targets: 1, searchable: false, orderable: false },                           // No.
                { targets: 7, searchable: false, orderable: false }                            // Action
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
    // The empty message is passed here rather than injected into the
    // page's HTML: a <tr><td colspan> inside the tbody is counted by
    // DataTables as a real row, so the column count no longer matches
    // and the table breaks.
    var emptyMsg = function (icon, title, hint) {
        return '<div class="empty-state">' +
               '<i class="bi bi-' + icon + '"></i>' +
               '<strong>' + title + '</strong>' +
               '<span>' + hint + '</span>' +
               '</div>';
    };

    if ($('#subjectTable').length) {
        $('#subjectTable').DataTable({
            language: {
                emptyTable: emptyMsg('journal-x', 'No subjects yet',
                    'Add the first one using the form on the left.')
            }
        });
    }

    if ($('#assignmentTable').length) {
        $('#assignmentTable').DataTable({
            language: {
                emptyTable: emptyMsg('inbox', 'No assignments yet',
                    'Use the form on the left to create one.')
            }
        });
    }

    // #usersTable is no longer initialised here: it needs its own
    // config (hidden search box, role and status filters) and that
    // lives in assets/js/userManagement.js. Initialising one table
    // twice makes DataTables throw "Cannot reinitialise".

});