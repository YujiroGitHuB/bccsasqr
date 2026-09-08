const Toast = Swal.mixin({
    toast: true,
    position: 'top-end',
    showConfirmButton: false,
    timer: 2500,
    timerProgressBar: true,
    background: '#1a1a2e',
    color: '#fff'
});

const swalTheme = { background: '#1a1a2e', color: '#fff', confirmButtonColor: '#667eea' };

// Escapes a value on its way into an HTML attribute. The rows are
// built here by hand now, so nothing else does it for us — and a
// student called O'Brien used to break the old inline onclick.
function esc(v) {
    return String(v === null || v === undefined ? '' : v)
        .replace(/&/g, '&amp;').replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ── DataTable ─────────────────────────────────────────────────────────
// The rows arrive as JSON from get_enrollment_data_ajax.php instead of
// being rendered into the page by PHP. At 1,586 enrollments that was
// 3.1 MB of markup the browser had to parse before the first five rows
// could show; DataTables now builds the DOM for the current page only.
// Same treatment students.php already had.
let enrollDT;
$(document).ready(function () {
    if ($.fn.DataTable.isDataTable('#enrollTable')) {
        $('#enrollTable').DataTable().destroy();
    }

    const escText = $.fn.dataTable.render.text();

    enrollDT = $('#enrollTable').DataTable({
        ajax: {
            url: 'get_enrollment_data_ajax.php?dataset=enrollments',
            dataSrc: function (res) {
                if (!res.success) {
                    Swal.fire({
                        icon: 'error', title: 'Error',
                        text: res.message || 'Could not load the enrollments.',
                        ...swalTheme
                    });
                    return [];
                }
                // The badges were counted server-side for the first
                // paint; this keeps them honest if the roster changed
                // between that count and this fetch.
                setEnrollCount(res.data.length);
                return res.data;
            }
        },
        columns: [
            {
                data: null,
                render: function (row) {
                    const uid = 'chk-' + esc(row.id);
                    return '<div class="table-checkbox-container">' +
                        '<input type="checkbox" class="table-checkbox-input row-check"' +
                        ' id="' + uid + '" data-id="' + esc(row.id) + '"' +
                        ' data-name="' + esc(row.fullname) + '"' +
                        ' data-subject="' + esc(row.subject_name) + '">' +
                        '<label class="table-checkbox-label" for="' + uid + '">' +
                        '<div class="table-checkbox-box"><i class="bi bi-check"></i></div>' +
                        '</label></div>';
                }
            },
            { data: 'student_no',   render: escText },
            { data: 'fullname',     render: escText },
            { data: 'full_section', render: escText },
            {
                data: null,
                render: function (row, type) {
                    // Sorting and searching run on the plain text —
                    // otherwise a search for "ITE" would also match the
                    // class names in the markup.
                    if (type !== 'display') {
                        return row.subject_code + ' ' + row.subject_name;
                    }
                    return '<span class="badge-subject">' + esc(row.subject_code) + '</span>' +
                        ' <span class="ms-1">' + esc(row.subject_name) + '</span>';
                }
            },
            {
                data: null,
                render: function (row) {
                    // data-* rather than an inline onclick: an
                    // apostrophe in a name cannot break it.
                    return '<button class="btn btn-sm btn-danger btn-remove-enroll"' +
                        ' data-id="' + esc(row.id) + '"' +
                        ' data-name="' + esc(row.fullname) + '"' +
                        ' data-subject="' + esc(row.subject_name) + '">' +
                        '<i class="bi bi-trash"></i></button>';
                }
            }
        ],
        // The <tr> id the rest of this file removes rows by.
        createdRow: function (row, data) {
            row.id = 'enroll-row-' + data.id;
        },
        responsive: true,
        pageLength: 5,
        lengthMenu: [[5, 10, 25, 50, 100, -1], [5, 10, 25, 50, 100, "All"]],
        order: [[3, 'asc'], [2, 'asc']],
        columnDefs: [{ orderable: false, targets: [0, 5] }],
        language: {
            emptyTable: "No enrollments yet",
            zeroRecords: "No matching records found",
            loadingRecords: "Loading enrollments..."
        }
    });

    // Delegated, so they keep working on rows DataTables rebuilds on
    // every draw — a handler bound to a row would not survive paging.
    $('#enrollTable').on('change', '.row-check', onRowCheckChange);
    $('#enrollTable').on('click', '.btn-remove-enroll', function () {
        removeEnrollment(Number(this.dataset.id), this.dataset.name, this.dataset.subject);
    });

    // The checkboxes are per page and the boxes are redrawn on every
    // page change, so a leftover selection would count rows that are
    // no longer on screen.
    $('#enrollTable').on('page.dt search.dt order.dt length.dt', function () {
        clearSelection();
    });
});

// ── Select All ────────────────────────────────────────────────────────
document.getElementById('selectAll').addEventListener('change', function () {
    const checked = this.checked;
    enrollDT.rows({ page: 'current' }).nodes().each(function (row) {
        const cb = row.querySelector('.row-check');
        if (cb) {
            cb.checked = checked;
            row.classList.toggle('row-selected', checked);
        }
    });
    updateBulkBar();
});

function onRowCheckChange() {
    const total = enrollDT.rows({ page: 'current' }).nodes().length;
    const checked = document.querySelectorAll('.row-check:checked').length;
    document.getElementById('selectAll').checked = checked === total && total > 0;
    document.getElementById('selectAll').indeterminate = checked > 0 && checked < total;
    this.closest('tr').classList.toggle('row-selected', this.checked);
    updateBulkBar();
}

function updateBulkBar() {
    const count = document.querySelectorAll('.row-check:checked').length;
    document.getElementById('selectedCount').textContent = count;
    document.getElementById('bulkActionBar').style.display = count > 0 ? 'block' : 'none';
}

function clearSelection() {
    document.querySelectorAll('.row-check:checked').forEach(cb => {
        cb.checked = false;
        cb.closest('tr').classList.remove('row-selected');
    });
    document.getElementById('selectAll').checked = false;
    document.getElementById('selectAll').indeterminate = false;
    updateBulkBar();
}

// ── Delete Selected ───────────────────────────────────────────────────
function deleteSelected() {
    const checked = document.querySelectorAll('.row-check:checked');
    if (!checked.length) return;

    const ids = Array.from(checked).map(cb => parseInt(cb.dataset.id));
    const names = [...new Set(Array.from(checked).map(cb => cb.dataset.name))];
    const preview = names.slice(0, 3).join(', ') + (names.length > 3 ? ` +${names.length - 3} more` : '');

    Swal.fire({
        icon: 'warning',
        title: `Delete ${ids.length} Enrollment(s)?`,
        html: `<p>Students: <strong>${preview}</strong></p>
                       <p class="text-danger small mt-1">This cannot be undone.</p>`,
        showCancelButton: true,
        confirmButtonText: `Yes, Delete ${ids.length}`,
        confirmButtonColor: '#f5576c',
        ...swalTheme
    }).then(result => {
        if (!result.isConfirmed) return;

        Swal.fire({ title: 'Deleting...', allowOutsideClick: false, didOpen: () => Swal.showLoading(), ...swalTheme });

        fetch('../crud/manage_student_subjects.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'bulk_remove', ids })
        })
            .then(r => r.json())
            .then(res => {
                if (res.success) {
                    ids.forEach(id => enrollDT.row($('#enroll-row-' + id)).remove());
                    enrollDT.draw(false);
                    updateEnrollCount(-ids.length);
                    clearSelection();
                    Swal.fire({ icon: 'success', title: `${res.deleted} enrollment(s) deleted!`, timer: 1800, showConfirmButton: false, ...swalTheme });
                } else {
                    Swal.fire({ icon: 'error', title: 'Error', text: res.error, ...swalTheme });
                }
            })
            .catch(() => Swal.fire({ icon: 'error', title: 'Network Error', ...swalTheme }));
    });
}

// ── Tab switch ────────────────────────────────────────────────────────
function switchEnrollTab(tab, btn) {
    document.querySelectorAll('.enroll-tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.enroll-tab-btn').forEach(b => b.classList.remove('active'));
    document.getElementById('enroll-tab-' + tab).classList.add('active');
    btn.classList.add('active');
}

// ══════════════════════════════════════════════════════════════════════
//  Generic Searchable Dropdown Engine
// ══════════════════════════════════════════════════════════════════════
const _sdOpen = {};

function sdToggle(id) {
    _sdOpen[id] ? sdClose(id) : sdOpen(id);
}

function sdOpen(id) {
    Object.keys(_sdOpen).forEach(k => { if (_sdOpen[k]) sdClose(k); });
    document.getElementById('sd-panel-' + id).classList.add('open');
    document.getElementById('sd-btn-' + id).classList.add('open');
    const inp = document.querySelector('#sd-panel-' + id + ' input[type=text]');
    if (inp) { inp.value = ''; sdFilter(id, ''); setTimeout(() => inp.focus(), 50); }
    _sdOpen[id] = true;
}

function sdClose(id) {
    document.getElementById('sd-panel-' + id)?.classList.remove('open');
    document.getElementById('sd-btn-' + id)?.classList.remove('open');
    _sdOpen[id] = false;
}

function sdSelect(id, value, label, el, isReset = false) {
    document.getElementById(id).value = value;
    const txt = document.getElementById('sd-txt-' + id);
    if (isReset || !value) {
        txt.textContent = label;
        txt.classList.add('sd-placeholder');
    } else {
        txt.textContent = label;
        txt.classList.remove('sd-placeholder');
    }
    document.querySelectorAll('#sd-list-' + id + ' .sd-item')
        .forEach(i => i.classList.remove('selected'));
    if (el) el.classList.add('selected');
    sdClose(id);
}

function sdFilter(id, query) {
    const q = query.toLowerCase().trim();
    const list = document.getElementById('sd-list-' + id);
    list.querySelector('.sd-empty')?.remove();

    const items = list.querySelectorAll('.sd-item');
    const groups = list.querySelectorAll('.sd-group');
    let hasAny = false;

    items.forEach(item => {
        const label = (item.dataset.label || '').toLowerCase();
        const search = (item.dataset.search || label);
        const match = !q || search.includes(q) || label.includes(q);
        item.style.display = match ? 'flex' : 'none';
        if (match) hasAny = true;
    });

    groups.forEach(grp => {
        const gName = grp.dataset.group;
        const visible = Array.from(items).some(
            i => i.dataset.group === gName && i.style.display !== 'none'
        );
        grp.style.display = visible ? 'block' : 'none';
    });

    if (!hasAny) {
        const div = document.createElement('div');
        div.className = 'sd-empty';
        div.innerHTML = '<i class="bi bi-search"></i>No results found';
        list.appendChild(div);
    }
}

function sdKeydown(e, id) {
    const items = Array.from(
        document.querySelectorAll('#sd-list-' + id + ' .sd-item')
    ).filter(i => i.style.display !== 'none');

    const focused = document.querySelector('#sd-list-' + id + ' .sd-item.focused');
    let idx = items.indexOf(focused);

    if (e.key === 'ArrowDown') {
        e.preventDefault();
        focused?.classList.remove('focused');
        items[(idx + 1) % items.length]?.classList.add('focused');
        items[(idx + 1) % items.length]?.scrollIntoView({ block: 'nearest' });
    } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        focused?.classList.remove('focused');
        const prev = (idx - 1 + items.length) % items.length;
        items[prev]?.classList.add('focused');
        items[prev]?.scrollIntoView({ block: 'nearest' });
    } else if (e.key === 'Enter') {
        e.preventDefault();
        focused?.click();
    } else if (e.key === 'Escape') {
        sdClose(id);
    }
}

function sdSelectSection(sectionInputId, courseInputId, rawSection, course, fullLabel, el) {
    document.getElementById(sectionInputId).value = rawSection;
    document.getElementById(courseInputId).value = course;

    const txt = document.getElementById('sd-txt-' + sectionInputId);
    txt.innerHTML = `<span class="sd-course-pill">${course}</span>&nbsp;${rawSection}`;
    txt.classList.remove('sd-placeholder');

    document.querySelectorAll('#sd-list-' + sectionInputId + ' .sd-item')
        .forEach(i => i.classList.remove('selected'));
    el?.classList.add('selected');

    sdClose(sectionInputId);
}

document.addEventListener('click', function (e) {
    Object.keys(_sdOpen).forEach(id => {
        const wrap = document.getElementById('sd-wrap-' + id);
        if (wrap && !wrap.contains(e.target)) sdClose(id);
    });
    if (!document.getElementById('studentDropdown')?.contains(e.target)) {
        closeStudentDropdown();
    }
});

// ── Student Dropdown ──────────────────────────────────────────────────
// The roster is fetched once, the first time the dropdown is opened,
// and only the students the search actually matches are ever put in
// the DOM. Every student in the school used to be written into the
// page as a <div> carrying seven data- attributes — 1.2 MB of markup,
// nearly all of it never looked at, and re-scanned on every keystroke.
let studentDropdownOpen = false;
let enrollStudents = null;      // null = not fetched yet
let studentsLoading = false;
let studentsFailed = false;

// The chosen student is kept HERE rather than read back off a
// .selected element. The list is rebuilt on every keystroke now, so
// the element that was clicked may well be gone by the time Assign is
// pressed.
let selectedStudent = null;

// How many names to draw at once. Nobody scrolls 1,500 rows to find
// someone — they type. Drawing the lot on every keystroke is what made
// the old list stutter.
const STUDENT_RENDER_LIMIT = 60;

function toggleStudentDropdown() {
    studentDropdownOpen ? closeStudentDropdown() : openStudentDropdown();
}

function openStudentDropdown() {
    document.getElementById('studentPanel').classList.add('open');
    document.getElementById('studentTrigger').classList.add('open');
    document.getElementById('studentSearch').value = '';
    studentDropdownOpen = true;

    loadStudents().then(() => filterStudentList(''));
    setTimeout(() => document.getElementById('studentSearch').focus(), 50);
}

function closeStudentDropdown() {
    document.getElementById('studentPanel').classList.remove('open');
    document.getElementById('studentTrigger').classList.remove('open');
    studentDropdownOpen = false;
}

// Resolves once the roster is in memory. Safe to call again — the
// second open does not re-fetch, and a call made while the first is
// still in flight joins it instead of starting a race.
function loadStudents() {
    if (enrollStudents) return Promise.resolve();
    if (studentsLoading) return studentsLoading;

    studentListMessage('bi-hourglass-split', 'Loading students...');

    studentsLoading = fetch('get_enrollment_data_ajax.php?dataset=students')
        .then(r => r.json())
        .then(res => {
            if (!res.success) throw new Error(res.message || 'refused');
            enrollStudents = res.data;
            studentsFailed = false;
        })
        .catch(() => {
            // enrollStudents is left null, not [], so the next open
            // tries again instead of insisting the school has nobody.
            studentsFailed = true;
        })
        .finally(() => {
            studentsLoading = false;
        });

    return studentsLoading;
}

function studentListMessage(icon, text) {
    document.getElementById('studentList').innerHTML =
        '<div class="sd-empty"><i class="bi ' + icon + '"></i>' + esc(text) + '</div>';
}

// Builds the list from scratch for the current search and section
// filter. Replaces the old filterStudentList(), which walked ~1,500
// existing nodes and toggled style.display on every one of them.
function filterStudentList(query) {
    const list = document.getElementById('studentList');

    if (studentsFailed) {
        studentListMessage('bi-wifi-off', 'Could not load the student list. Close and reopen this to retry.');
        return;
    }
    if (!enrollStudents) {
        studentListMessage('bi-hourglass-split', 'Loading students...');
        return;
    }

    const q = query.toLowerCase().trim();
    const sectionFilter = document.getElementById('filterSection').value;

    const matches = enrollStudents.filter(s => {
        const fullSec = s.course + '-' + s.section;
        if (sectionFilter && fullSec !== sectionFilter) return false;
        if (!q) return true;
        return s.fullname.toLowerCase().includes(q) ||
               s.student_no.toLowerCase().includes(q);
    });

    if (!matches.length) {
        studentListMessage('bi-search', 'No students found');
        return;
    }

    // The endpoint already sorts by course, section, then name, so a
    // course heading is needed only where the course changes.
    const shown = matches.slice(0, STUDENT_RENDER_LIMIT);
    let html = '';
    let course = null;

    shown.forEach(s => {
        if (s.course !== course) {
            course = s.course;
            html += '<div class="sd-group" data-group="' + esc(course) + '">' +
                    '<i class="bi bi-mortarboard me-1"></i>' + esc(course) + '</div>';
        }
        const fullSec = s.course + '-' + s.section;
        const isSel = selectedStudent && selectedStudent.student_no === s.student_no;
        html += '<div class="sd-item' + (isSel ? ' selected' : '') + '"' +
                ' data-value="' + esc(s.student_no) + '"' +
                ' data-name="' + esc(s.fullname) + '"' +
                ' data-full-section="' + esc(fullSec) + '"' +
                ' data-course="' + esc(s.course) + '"' +
                ' data-section="' + esc(s.section) + '"' +
                ' data-group="' + esc(s.course) + '">' +
                '<span class="sd-sec-badge">' + esc(fullSec) + '</span>' +
                '<span>' + esc(s.fullname) + '</span>' +
                '<span class="sd-stuno">' + esc(s.student_no) + '</span>' +
                '</div>';
    });

    if (matches.length > shown.length) {
        html += '<div class="sd-empty">Showing ' + shown.length + ' of ' +
                matches.length + ' — keep typing to narrow it down</div>';
    }

    list.innerHTML = html;
}

// One delegated handler, because the items are replaced on every
// keystroke and a listener bound to them would not survive. Bound at
// the top level like the #selectAll handler above — this file runs at
// the end of the body, so the element is already there.
document.getElementById('studentList').addEventListener('click', function (e) {
    const item = e.target.closest('.sd-item');
    if (item) selectStudent(item);
});

function selectStudent(el) {
    selectedStudent = {
        student_no: el.dataset.value,
        fullname: el.dataset.name,
        course: el.dataset.course,
        section: el.dataset.section,
        full_section: el.dataset.fullSection
    };

    document.getElementById('enrollStudentSelect').value = selectedStudent.student_no;

    const trigText = document.getElementById('studentTriggerText');
    trigText.textContent = `[${selectedStudent.full_section}] ${selectedStudent.fullname}`;
    trigText.classList.remove('sd-placeholder');

    document.querySelectorAll('#studentList .sd-item').forEach(i => i.classList.remove('selected'));
    el.classList.add('selected');

    closeStudentDropdown();

    const rawSec = selectedStudent.section;
    const crs = selectedStudent.course;
    if (rawSec && crs) {
        sdSelectSection('enrollSectionSelect', 'enrollCourseSelect', rawSec, crs, selectedStudent.full_section,
            document.querySelector(`#sd-list-enrollSectionSelect .sd-item[data-value="${rawSec}"][data-course="${crs}"]`)
        );
    }
}

function studentSearchKeydown(e) {
    // Everything rendered is visible now — the old version had to skip
    // the ~1,500 items it had hidden with style.display.
    const items = Array.from(document.querySelectorAll('#studentList .sd-item'));
    if (!items.length) return;

    const focused = document.querySelector('#studentList .sd-item.focused');
    let idx = items.indexOf(focused);

    if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (focused) focused.classList.remove('focused');
        idx = (idx + 1) % items.length;
        items[idx]?.classList.add('focused');
        items[idx]?.scrollIntoView({ block: 'nearest' });
    } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (focused) focused.classList.remove('focused');
        idx = (idx - 1 + items.length) % items.length;
        items[idx]?.classList.add('focused');
        items[idx]?.scrollIntoView({ block: 'nearest' });
    } else if (e.key === 'Enter') {
        e.preventDefault();
        if (focused) selectStudent(focused);
    } else if (e.key === 'Escape') {
        closeStudentDropdown();
    }
}

// ── Filter by Section ─────────────────────────────────────────────────
function filterEnrollStudents() {
    document.getElementById('enrollStudentSelect').value = '';
    selectedStudent = null;
    const trigText = document.getElementById('studentTriggerText');
    trigText.textContent = '-- Select Student --';
    trigText.classList.add('sd-placeholder');
    filterStudentList(document.getElementById('studentSearch')?.value || '');
}

// ── Assign Individual ─────────────────────────────────────────────────
function assignIndividual() {
    const studentNo = document.getElementById('enrollStudentSelect').value;
    // From the tracked selection, not from the list: the item that was
    // clicked is gone as soon as the search text changes.
    const studentName = selectedStudent ? selectedStudent.fullname : '';
    const subjectCode = document.getElementById('enrollSubjectSelect').value;
    const subjectName = document.getElementById('sd-txt-enrollSubjectSelect')?.textContent.trim() || '';
    const section = document.getElementById('enrollSectionSelect').value;

    if (!studentNo || !subjectCode || !section) {
        Swal.fire({ icon: 'warning', title: 'Incomplete', text: 'Please fill in all fields.', ...swalTheme });
        return;
    }

    Swal.fire({
        icon: 'question',
        title: 'Confirm Assignment',
        html: `Assign <strong>${subjectName}</strong><br>to <strong>${studentName}</strong> (Section ${section})?`,
        showCancelButton: true,
        confirmButtonText: 'Yes, Assign',
        ...swalTheme
    }).then(result => {
        if (!result.isConfirmed) return;

        const course = document.getElementById('enrollCourseSelect').value;
        fetch('../crud/manage_student_subjects.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'assign', student_no: studentNo, subject_code: subjectCode, section, course })
        })
            .then(r => r.json())
            .then(res => {
                if (res.success) {
                    Toast.fire({ icon: 'success', title: res.message });
                    // add the course parameter
                    addEnrollRow(res.id, studentNo, studentName, section, course, subjectCode, subjectName);
                    updateEnrollCount(1);
                } else {
                    Swal.fire({ icon: 'error', title: 'Error', text: res.error, ...swalTheme });
                }
            });
    });
}

// ── Bulk Assign ───────────────────────────────────────────────────────
function assignBulk() {
    const section = document.getElementById('bulkSection').value;
    const bulkCourse = document.getElementById('bulkSectionCourse').value;
    const subjectCode = document.getElementById('bulkSubject').value;
    const subjectName = document.getElementById('sd-txt-bulkSubject')?.textContent.trim() || '';

    if (!section || !subjectCode) {
        Swal.fire({ icon: 'warning', title: 'Incomplete', text: 'Please select both section and subject.', ...swalTheme });
        return;
    }

    const displaySection = bulkCourse ? `${bulkCourse}-${section}` : section;

    Swal.fire({
        icon: 'question',
        title: 'Bulk Assign',
        html: `Assign <strong>${subjectName}</strong> to <strong>ALL students in Section ${displaySection}</strong>?<br>
                       <small style="color:#adb5bd">Already enrolled students will be skipped.</small>`,
        showCancelButton: true,
        confirmButtonText: 'Yes, Bulk Assign',
        ...swalTheme
    }).then(result => {
        if (!result.isConfirmed) return;

        Swal.fire({ title: 'Processing...', allowOutsideClick: false, didOpen: () => Swal.showLoading(), ...swalTheme });

        fetch('../crud/manage_student_subjects.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'bulk_assign', section, course: bulkCourse, subject_code: subjectCode })
        })
            .then(r => r.json())
            .then(res => {
                if (res.success) {
                    Swal.fire({
                        icon: 'success', title: 'Bulk Assigned!',
                        html: `Assigned: <strong>${res.assigned}</strong><br>Skipped: <strong>${res.skipped}</strong>`,
                        ...swalTheme
                    });
                    if (res.assigned > 0) {
                        res.rows.forEach(row => addEnrollRow(
                            row.id, row.student_no, row.fullname,
                            section, bulkCourse,   // ← dagdag na course
                            subjectCode, subjectName
                        ));
                    }
                } else {
                    Swal.fire({ icon: 'error', title: 'Error', text: res.error, ...swalTheme });
                }
            });
    });
}

// ── Remove single ─────────────────────────────────────────────────────
function removeEnrollment(id, studentName, subjectName) {
    Swal.fire({
        icon: 'warning',
        title: 'Remove Enrollment?',
        html: `Remove <strong>${subjectName}</strong> from <strong>${studentName}</strong>?`,
        showCancelButton: true,
        confirmButtonText: 'Yes, Remove',
        confirmButtonColor: '#f5576c',
        ...swalTheme
    }).then(result => {
        if (!result.isConfirmed) return;

        fetch('../crud/manage_student_subjects.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'remove', id })
        })
            .then(r => r.json())
            .then(res => {
                if (res.success) {
                    enrollDT.row($('#enroll-row-' + id)).remove().draw();
                    updateEnrollCount(-1);
                    updateBulkBar();
                    Toast.fire({ icon: 'success', title: 'Enrollment removed!' });
                } else {
                    Swal.fire({ icon: 'error', title: 'Error', text: res.error, ...swalTheme });
                }
            });
    });
}

// ── Add row to DataTable ──────────────────────────────────────────────
// Takes the same shape the endpoint sends, so a row added here and a
// row that arrived from the server render through the identical
// column definitions — the markup is written in exactly one place.
function addEnrollRow(id, studentNo, name, section, course, subjectCode, subjectName) {
    enrollDT.row.add({
        id: id,
        student_no: studentNo,
        fullname: name,
        course: course,
        section: section,
        full_section: course ? `${course}-${section}` : section,
        subject_code: subjectCode,
        subject_name: subjectName
    }).draw(false);
}

// ── Count badges ──────────────────────────────────────────────────────
// Two of them: the chip in the hero and the one beside the table
// heading. PHP counts them for the first paint; these keep them in
// step afterwards.
function setEnrollCount(total) {
    ['enrollCount', 'tableCount'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.textContent = total;
    });
}

function updateEnrollCount(delta) {
    ['enrollCount', 'tableCount'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.textContent = (parseInt(el.textContent, 10) || 0) + delta;
    });
}
