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

// ── DataTable ─────────────────────────────────────────────────────────
let enrollDT;
$(document).ready(function () {
    if ($.fn.DataTable.isDataTable('#enrollTable')) {
        $('#enrollTable').DataTable().destroy();
    }

    enrollDT = $('#enrollTable').DataTable({
        responsive: true,
        pageLength: 5,
        lengthMenu: [[5, 10, 25, 50, 100, -1], [5, 10, 25, 50, 100, "All"]],
        order: [[3, 'asc'], [2, 'asc']],
        columnDefs: [{ orderable: false, targets: [0, 5] }],
        language: {
            emptyTable: "No enrollments yet",
            zeroRecords: "No matching records found"
        }
    });

    $('#enrollTable').on('change', '.row-check', onRowCheckChange);
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
let studentDropdownOpen = false;

function toggleStudentDropdown() {
    studentDropdownOpen ? closeStudentDropdown() : openStudentDropdown();
}

function openStudentDropdown() {
    document.getElementById('studentPanel').classList.add('open');
    document.getElementById('studentTrigger').classList.add('open');
    document.getElementById('studentSearch').value = '';
    filterStudentList('');
    setTimeout(() => document.getElementById('studentSearch').focus(), 50);
    studentDropdownOpen = true;
}

function closeStudentDropdown() {
    document.getElementById('studentPanel').classList.remove('open');
    document.getElementById('studentTrigger').classList.remove('open');
    studentDropdownOpen = false;
}

function selectStudent(el) {
    const val = el.dataset.value;
    const name = el.dataset.name;
    const fullSec = el.dataset.fullSection;

    document.getElementById('enrollStudentSelect').value = val;

    const trigText = document.getElementById('studentTriggerText');
    trigText.textContent = `[${fullSec}] ${name}`;
    trigText.classList.remove('sd-placeholder');

    document.querySelectorAll('#studentList .sd-item').forEach(i => i.classList.remove('selected'));
    el.classList.add('selected');

    closeStudentDropdown();

    const rawSec = el.dataset.section;
    const crs = el.dataset.course;
    const fullS = el.dataset.fullSection;
    if (rawSec && crs) {
        sdSelectSection('enrollSectionSelect', 'enrollCourseSelect', rawSec, crs, fullS,
            document.querySelector(`#sd-list-enrollSectionSelect .sd-item[data-value="${rawSec}"][data-course="${crs}"]`)
        );
    }
}

function filterStudentList(query) {
    const q = query.toLowerCase().trim();
    const sectionFilter = document.getElementById('filterSection').value;
    const list = document.getElementById('studentList');
    let hasResults = false;

    list.querySelector('.sd-empty')?.remove();

    const items = list.querySelectorAll('.sd-item');
    const groups = list.querySelectorAll('.sd-group');

    items.forEach(item => {
        const name = item.dataset.name.toLowerCase();
        const stuno = item.dataset.value.toLowerCase();
        const fullSec = item.dataset.fullSection;

        const matchSearch = !q || name.includes(q) || stuno.includes(q);
        const matchSection = !sectionFilter || fullSec === sectionFilter;

        item.style.display = (matchSearch && matchSection) ? 'flex' : 'none';
        if (matchSearch && matchSection) hasResults = true;
    });

    groups.forEach(grp => {
        const groupName = grp.dataset.group;
        const anyVisible = Array.from(items).some(item =>
            item.dataset.group === groupName && item.style.display !== 'none'
        );
        grp.style.display = anyVisible ? 'block' : 'none';
    });

    if (!hasResults) {
        const empty = document.createElement('div');
        empty.className = 'sd-empty';
        empty.innerHTML = '<i class="bi bi-search"></i>No students found';
        list.appendChild(empty);
    }
}

function studentSearchKeydown(e) {
    const items = Array.from(document.querySelectorAll('#studentList .sd-item'))
        .filter(i => i.style.display !== 'none');
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
    const trigText = document.getElementById('studentTriggerText');
    trigText.textContent = '-- Select Student --';
    trigText.classList.add('sd-placeholder');
    document.querySelectorAll('#studentList .sd-item').forEach(i => i.classList.remove('selected'));
    filterStudentList(document.getElementById('studentSearch')?.value || '');
}

// ── Assign Individual ─────────────────────────────────────────────────
function assignIndividual() {
    const studentNo = document.getElementById('enrollStudentSelect').value;
    const selectedItem = document.querySelector('#studentList .sd-item.selected');
    const studentName = selectedItem ? selectedItem.dataset.name : '';
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
                    // idagdag ang course parameter
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
function addEnrollRow(id, studentNo, name, section, course, subjectCode, subjectName) {
    const uid = `chk-${id}`;
    const fullSection = course ? `${course}-${section}` : section;

    const node = enrollDT.row.add([
        `<div class="table-checkbox-container">
                    <input type="checkbox" class="table-checkbox-input row-check"
                        id="${uid}" data-id="${id}"
                        data-name="${name}" data-subject="${subjectName}">
                    <label class="table-checkbox-label" for="${uid}">
                        <div class="table-checkbox-box"><i class="bi bi-check"></i></div>
                    </label>
                </div>`,
        studentNo,
        name,
        fullSection,
        `<span class="badge-subject">${subjectCode}</span> <span class="ms-1">${subjectName}</span>`,
        `<button class="btn btn-sm btn-danger"
                    onclick="removeEnrollment(${id},'${name}','${subjectName}')">
                    <i class="bi bi-trash"></i>
                </button>`
    ]).draw(false).node();
    $(node).attr('id', 'enroll-row-' + id);
    $(node).find('.row-check').on('change', onRowCheckChange);
}

// ── Update count badge ────────────────────────────────────────────────
function updateEnrollCount(delta) {
    ['enrollCount', 'tableCount'].forEach(id => {
        const el = document.getElementById(id);
        if (el) el.textContent = parseInt(el.textContent) + delta;
    });
}