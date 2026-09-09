$(document).ready(function () {

    // The Copy/CSV/Excel/PDF/Print buttons were removed from all three
    // tables here. They pulled in five extra CDN scripts (DataTables
    // Buttons, its HTML5 and print modules, JSZip, and pdfmake with its
    // font file — pdfmake alone is the heaviest script on the page) to
    // duplicate exports the app already does server-side, properly
    // formatted, in exports/export_pdf.php and
    // exports/export_absences_pdf.php.
    //
    // The `systemName` variable that titled those exports went with
    // them; it was a hardcoded copy of what system_settings_tbl holds
    // and had already drifted from it.

    // ================================================================
    // ATTENDANCE TABLE (#example)
    // ================================================================
    if ($('#example').length) {
        // Ang mga hilera ay dumarating na ngayong JSON, gaya ng
        // #stud_tbl sa ibaba.
        //
        // Dati ay isinusulat ng attendance.php ang BAWAT hilera bilang
        // HTML at ang DataTables ang nagtatago ng iba. Ang pageLength
        // ay hindi kailanman naglimita ng kinukuha — 1,476 bytes kada
        // hilera, 1 MB sa 710, at lumalaki sa bawat pumapasok. Sa
        // hosting na naghahatid ng 60–120 KB kada segundo, iyon ay
        // pito hanggang labingwalong segundong paghihintay bago pa
        // may makita.
        var att      = window.attendanceTable || {};
        var mayDelete = att.delete === true;

        var escAtt = $.fn.dataTable.render.text();

        // Para sa markup na binubuo rito nang mano-mano, ang halaga ay
        // dapat na-escape bago ipasok sa isang attribute — pareho ng
        // ginagawa ng #stud_tbl.
        var attrAtt = function (v) {
            return String(v === null || v === undefined ? '' : v)
                .replace(/&/g, '&amp;').replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        };

        $('#example').DataTable({
            // serverSide: ang hinihingi lamang ng nakabukas na pahina
            // ang umaalis ng database. Kasama rito ang search, ang sort
            // at ang section filter — wala silang pagpipilian, dahil
            // hindi mahahanap ng browser ang hilerang hindi naman nito
            // hawak.
            serverSide: true,
            // Ang paghahanap ay isang tanong sa server kada pindot ng
            // letra kung walang antala. 400ms: sapat para matapos ang
            // isang salita, hindi pa nararamdamang mabagal.
            searchDelay: 400,
            ajax: {
                url: 'get_attendance_ajax.php',
                // Ang parehong bintanang nakasulat sa From at To, at
                // ang section mula sa dropdown. Kapag hindi ipinasa
                // ang mga ito, ang sariling default ng endpoint ang
                // susundin, at ang talahanayan ay hindi na tutugma sa
                // mga kontrol sa itaas nito.
                data: function (d) {
                    d.from    = att.from || '';
                    d.to      = att.to   || '';
                    d.section = $('#filterSection').val() || '';
                },
                dataSrc: function (res) {
                    $('#tableLoader').hide();
                    $('#tableContainer').show();

                    if (res.error) {
                        Swal.fire({
                            icon: 'error', title: 'Error!',
                            background: '#0f172a', color: '#e0e0e0',
                            text: res.error
                        });
                        return [];
                    }
                    return res.data;
                },
                error: function () {
                    // Kapag hindi umabot ang endpoint, ang loader ay
                    // maiiwang umiikot magpakailanman at mukhang
                    // mabagal lamang ang pahina. Mas mabuting sabihin.
                    $('#tableLoader').hide();
                    $('#tableContainer').show();
                    Swal.fire({
                        icon: 'error', title: 'Could not load the records',
                        background: '#0f172a', color: '#e0e0e0',
                        text: 'Please check your connection and refresh the page.'
                    });
                }
            },
            columns: [
                {
                    data: 'id',
                    render: function (id) {
                        // Nananatili ang hanay kahit walang permission —
                        // ang columnDefs sa ibaba ay tumutukoy sa
                        // pamamagitan ng index, at ang pagtanggal ng
                        // hanay dito ay maghihiwa sa bawat target.
                        if (!mayDelete) return '';
                        return '<input type="checkbox" class="rowCheck" value="' + attrAtt(id) + '">';
                    }
                },
                { data: null, defaultContent: '' },      // running No., punan ng drawCallback
                { data: 'date',       render: escAtt },
                { data: 'student_no', render: escAtt },
                { data: 'name',       render: escAtt },
                { data: 'course',     render: escAtt },
                // Tinanggal na ng endpoint ang unahang course
                // ("BSIT-2A" → "2A"), gaya ng dating ginagawa ng
                // cleanSection() sa pahina.
                { data: 'section',    render: escAtt },
                { data: 'time_in',    render: escAtt },
                { data: 'subject',    render: escAtt },
                {
                    data: 'id',
                    render: function (id) {
                        if (!mayDelete) return '';
                        return '<button class="btn-delete" data-id="' + attrAtt(id) + '">' +
                               '<i class="bi bi-trash"></i></button>';
                    }
                }
            ],
            createdRow: function (tr, data) {
                // Ang delete_attendance.js ay umaasa sa id na ito.
                tr.id = 'row-' + data.id;
            },
            dom: 'lfrtip',
            lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "All"]],
            // 25 at hindi 5. Noong nasa pahina na ang lahat ng hilera,
            // ang laki ng pahina ay tungkol sa haba ng screen. Ngayong
            // isang tanong sa server ang bawat pahina, ito ay tungkol
            // sa dami ng paghihintay: ang 25 ay mga limang kilobyte pa
            // rin, at limang beses na mas kaunti ang pagpindot.
            pageLength: 25,
            // Pinakabago muna, gaya ng dating ORDER BY date DESC ng
            // pahina. Kung walang nakatakda, ang hanay 0 (ang checkbox)
            // ang susundin ng DataTables.
            order: [[2, 'desc']],
            processing: true,
            language: {
                processing: '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>'
            },
            // Column 0 = checkbox, column 1 = running No.
            columnDefs: [
                { targets: 0, searchable: false, orderable: false, className: 'text-center' },
                { targets: 1, searchable: false, orderable: false },
                { targets: 9, searchable: false, orderable: false }   // Action
            ],
            drawCallback: function (settings) {
                var api = this.api();
                var startIndex = api.context[0]._iDisplayStart;
                api.column(1, { page: 'current' }).nodes().each(function (cell, i) {
                    cell.innerHTML = startIndex + i + 1;
                });
            }
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
            dom: 'lfrtip',
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
            }
        });

        $('#filterSummaryCourse').on('change',  function () { summaryTable.column(3).search(this.value).draw(); });
        $('#filterSummarySection').on('change', function () { summaryTable.column(4).search(this.value).draw(); });
        $('#filterSummarySubject').on('change', function () { summaryTable.column(5).search(this.value).draw(); });
        $('#resetSummaryFilters').on('click', function () {
            $('#filterSummaryCourse, #filterSummarySection, #filterSummarySubject').val('');
            summaryTable.search('').columns().search('').draw();
        });

        // Export PDF — copy the live filter values into the form's hidden
        // inputs at submit time. Read on submit rather than mirrored on
        // every change so the two cannot drift apart, and only the three
        // values travel: exports/export_summary_pdf.php re-runs the query
        // itself rather than trusting rows from the page.
        //
        // The form is only rendered with the attendance.export permission,
        // so guard on its presence.
        $('#exportSummaryForm').on('submit', function () {
            $('#exportSummaryCourse').val($('#filterSummaryCourse').val() || '');
            $('#exportSummarySection').val($('#filterSummarySection').val() || '');
            $('#exportSummarySubject').val($('#filterSummarySubject').val() || '');
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

        // What this user may do, published by pages/students.php. The
        // fallback is "no", so a page that forgets to set it renders a
        // read-only table rather than buttons that fail on submit.
        var studentPerms = window.studentPerms || {};
        var mayEdit      = studentPerms.manage === true;
        var mayDelete    = studentPerms.delete === true;

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
                        // The checkboxes exist to bulk-delete, so they go
                        // when that is not allowed. The column itself stays —
                        // columnDefs below addresses columns by index.
                        if (!mayDelete) return '';
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
                        var html = '';

                        if (mayEdit) {
                            html += '<button class="btn btn-sm btn-success me-2 btn-edit-student"' +
                                    ' data-id="'      + attr(row.id) + '"' +
                                    ' data-no="'      + attr(row.student_no) + '"' +
                                    ' data-fullname="' + attr(row.fullname) + '"' +
                                    ' data-course="'  + attr(row.course) + '"' +
                                    ' data-section="' + attr(row.section) + '">' +
                                    '<i class="bi bi-pencil-square"></i></button>';
                        }

                        if (mayDelete) {
                            html += '<button class="btn btn-sm btn-danger btn-deletes" data-id="' + attr(row.id) + '">' +
                                    '<i class="bi bi-trash"></i></button>';
                        }

                        return html;
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
                 '<"row"<"col-sm-12"tr>>' +
                 '<"row"<"col-sm-12 col-md-5"i><"col-sm-12 col-md-7"p>>',
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