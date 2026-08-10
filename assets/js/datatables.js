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
            // Isang beses lang — kunin ang summary sa pag-bukas ng tab.
            // Dati ay kasama na ito sa HTML ng bawat page load.
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
        // Ang mga row ay dumarating na bilang JSON mula sa
        // get_students_ajax.php — mas magaan nang ~74% kaysa sa HTML,
        // at ang DOM lang ng kasalukuyang page ang ginagawa ng DataTables.
        var escText = $.fn.dataTable.render.text();

        // Para sa markup na binubuo natin mismo (checkbox at buton),
        // kailangang i-escape ang halaga bago ipasok sa attribute.
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
                        // data-* attributes sa halip na inline onclick: hindi
                        // nasisira ng kudlit sa pangalan, at hindi umaasa sa
                        // pag-escape ng PHP sa loob ng JS string.
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
                // Umaasa ang delete at deleteSelected sa id na ito.
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
    // Ang mensahe kapag walang laman ay dito ipinapasa at hindi
    // isinisingit sa HTML ng page: ang isang <tr><td colspan> sa loob
    // ng tbody ay binibilang ng DataTables bilang tunay na row, kaya
    // hindi tugma ang bilang ng column at nasisira ang table.
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
                emptyTable: emptyMsg('journal-x', 'Wala pang subject',
                    'Idagdag ang una sa form sa kaliwa.')
            }
        });
    }

    if ($('#assignmentTable').length) {
        $('#assignmentTable').DataTable({
            language: {
                emptyTable: emptyMsg('inbox', 'Wala pang assignment',
                    'Gamitin ang form sa kaliwa para magtakda.')
            }
        });
    }

    if ($('#usersTable').length)      { $('#usersTable').DataTable(); }

});