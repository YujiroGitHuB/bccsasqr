$(document).ready(function () {
    var table = $('#example').DataTable();

    /**
     * Ang sagot ng server, object man o teksto.
     *
     * Ang JSON.parse(response) nang diretso ay tumatakbo lamang kapag
     * TEKSTO ang natanggap ni jQuery. Kapag nagpadala ang endpoint ng
     * `Content-Type: application/json` — gaya ng ginagawa ng
     * crud/delete_attendance.php at crud/delete_selected_attendance.php —
     * ay object na ang ibinibigay ni jQuery, at ang JSON.parse(object)
     * ay nagiging JSON.parse("[object Object]"): SyntaxError.
     *
     * Tahimik itong sumasabog. Ang exception ay nangyayari sa loob ng
     * success handler, kaya walang error dialog na lumalabas — nawawala
     * lang ang confirm at walang nangyayari sa hilera. Ganito naging
     * "walang epekto" ang isahang Delete nang matagal.
     *
     * Isang lugar na lamang ang paghawak nito, para hindi na maulit ang
     * pagkakaiba: dati ay tama ang Delete Selected at mali ang dalawa.
     */
    function parseRes(response) {
        return typeof response === 'string' ? JSON.parse(response) : response;
    }

    // ── Select + Delete Selected ────────────────────────────
    var selSwal = {
        background: '#121212', color: '#e0e0e0', iconColor: '#00e5ff',
        showCancelButton: true, confirmButtonText: 'Delete', cancelButtonText: 'Cancel',
        reverseButtons: true,
        customClass: {
            popup: 'modern-dark-popup', title: 'modern-dark-title',
            htmlContainer: 'modern-dark-text', confirmButton: 'modern-dark-confirm',
            cancelButton: 'modern-dark-cancel'
        }
    };

    function selectedIds() {
        var ids = [];
        table.rows({ search: 'applied' }).nodes().to$().find('.rowCheck:checked').each(function () {
            ids.push($(this).val());
        });
        return ids;
    }

    /**
     * Ang "709 records loaded" sa tabi ng Reset Filters.
     *
     * Isinusulat ito ng PHP sa pag-load at hindi na muling ginagalaw,
     * kaya matapos ang isang pagbura ay sinasabi nitong 709 habang
     * 708 na ang nasa talahanayan sa ibaba — at matapos ang Delete
     * All ay 709 pa rin habang wala nang natitira. Isa itong maliit
     * na numero, pero ito ang unang tinitingnan ng taong nagtatanong
     * kung tumalab ba ang pagbura.
     *
     * Ang bilang ng DataTables ang pinagkukunan, hindi ang sariling
     * pagbabawas: iisang pinagmumulan, kaya hindi sila maaaring
     * maghiwalay.
     */
    function refreshCount() {
        // page.info().recordsTotal at hindi rows().count(): sa
        // server-side ay ang nakabukas na pahina lamang ang hawak ng
        // browser, kaya ang rows().count() ay 25 — hindi ang kabuuan.
        // Ang bilang ng server ang totoo.
        var info = table.page.info();
        var n = info ? info.recordsTotal : 0;
        $('#attCount').text(n.toLocaleString() + ' record' + (n === 1 ? '' : 's') + ' total');
    }

    function refreshSelectBar() {
        var checks  = table.rows({ search: 'applied' }).nodes().to$().find('.rowCheck');
        var checked = checks.filter(':checked').length;
        var total   = checks.length;

        $('#deleteSelected').prop('disabled', checked === 0)
            .find('.btn-text').text(checked > 0 ? 'Delete Selected (' + checked + ')' : 'Delete Selected');

        var sa = $('#selectAllAttendance');
        sa.prop('checked', total > 0 && checked === total);
        sa.prop('indeterminate', checked > 0 && checked < total);
    }

    $('#selectAllAttendance').on('change', function () {
        var checked = this.checked;
        table.rows({ search: 'applied' }).nodes().to$().find('.rowCheck').prop('checked', checked);
        refreshSelectBar();
    });

    $(document).on('change', '.rowCheck', refreshSelectBar);

    // Isang kawit para sa lahat ng tatlong pagbura: dumadaan silang
    // lahat sa isang draw, kaya hindi na kailangang tandaan ng bawat
    // isa na i-update ang bilang. Tumatakbo rin ito sa paghahanap at
    // pag-uuri, kung saan walang nagbabago sa bilang — muling
    // isinusulat lamang ang parehong teksto.
    table.on('draw', function () {
        refreshSelectBar();
        refreshCount();
    });

    $('#deleteSelected').on('click', function () {
        var ids = selectedIds();
        if (ids.length === 0) return;

        Swal.fire({
            ...selSwal,
            title: 'Delete Selected?',
            text: 'Remove ' + ids.length + ' selected attendance record(s)?',
            icon: 'warning'
        }).then(function (result) {
            if (!result.isConfirmed) return;
            $.ajax({
                url: '../crud/delete_selected_attendance.php',
                method: 'POST',
                data: { ids: ids },
                success: function (response) {
                    var res = parseRes(response);
                    if (res.success) {
                        // Gaya ng isahang delete: ang server ang may
                        // hawak ng listahan, kaya ito ang tinatanong
                        // muli sa halip na tanggalin ang nasa pahina.
                        table.ajax.reload(null, false);
                        refreshSelectBar();
                        Swal.fire({
                            ...selSwal, icon: 'success', title: 'Deleted!',
                            text: (res.rows_deleted || ids.length) + ' record(s) removed.',
                            timer: 1500, showConfirmButton: false
                        });
                    } else {
                        Swal.fire({ ...selSwal, icon: 'error', title: 'Error!', text: res.message || 'Failed to delete selected.' });
                    }
                },
                error: function () {
                    Swal.fire({ ...selSwal, icon: 'error', title: 'Error!', text: 'Something went wrong.' });
                }
            });
        });
    });

    // Delete single record
    $(document).on('click', '.btn-delete', function () {
        const id = $(this).data('id');

        const swalOptions = {
            background: '#121212',
            color: '#e0e0e0',
            iconColor: '#00e5ff',
            showCancelButton: true,
            confirmButtonText: 'Delete',
            cancelButtonText: 'Cancel',
            reverseButtons: true,
            customClass: {
                popup: 'modern-dark-popup',
                title: 'modern-dark-title',
                htmlContainer: 'modern-dark-text',
                confirmButton: 'modern-dark-confirm',
                cancelButton: 'modern-dark-cancel'
            }
        };

        Swal.fire({
            ...swalOptions,
            title: 'Delete Record?',
            text: 'Are you sure you want to remove this attendance record?',
            icon: 'warning'
        }).then((result) => {
            if (result.isConfirmed) {
                $.ajax({
                    url: '../crud/delete_attendance.php',
                    method: 'POST',
                    data: { id: id },
                    success: function (response) {
                        const res = parseRes(response);
                        if (res.success) {
                            // Muling tanong sa server, hindi pagtanggal
                            // sa nasa pahina.
                            //
                            // Sa server-side ay ang server ang may hawak ng
                            // buong listahan; ang browser ay may dalawampu't
                            // limang hilera lamang. Ang pagtanggal ng isa
                            // rito ay mag-iiwan ng pahinang may dalawampu't
                            // apat, mali ang kabuuang bilang, at walang
                            // kapalit na hilera mula sa susunod na pahina.
                            // Ang reload ang kumukuha ng bagong pahina —
                            // tama ang bilang, puno ang pahina.
                            //
                            // `false` ang pangalawang argumento: manatili sa
                            // kasalukuyang pahina. Hindi ito paghahanap
                            // kundi pagbura ng isang hilera; walang dahilan
                            // para ibalik ang tao sa pahina 1.
                            $('#row-' + id).fadeOut(300, function () {
                                table.ajax.reload(null, false);
                                refreshSelectBar();
                            });
                            Swal.fire({
                                ...swalOptions,
                                icon: 'success',
                                title: 'Deleted!',
                                text: 'Record has been removed.',
                                timer: 1500,
                                showConfirmButton: false
                            });
                        } else {
                            Swal.fire({
                                ...swalOptions,
                                icon: 'error',
                                title: 'Error!',
                                text: 'Failed to delete record.'
                            });
                        }
                    },
                    error: function () {
                        Swal.fire({
                            ...swalOptions,
                            icon: 'error',
                            title: 'Error!',
                            text: 'Something went wrong.'
                        });
                    }
                });
            }
        });
    });

    // Delete all records
    $('#deleteAll').click(function () {
        const swalOptions = {
            background: '#121212',
            color: '#e0e0e0',
            iconColor: '#00e5ff',
            showCancelButton: true,
            confirmButtonText: 'Delete All',
            cancelButtonText: 'Cancel',
            reverseButtons: true,
            customClass: {
                popup: 'modern-dark-popup',
                title: 'modern-dark-title',
                htmlContainer: 'modern-dark-text',
                confirmButton: 'modern-dark-confirm',
                cancelButton: 'modern-dark-cancel'
            }
        };

        Swal.fire({
            ...swalOptions,
            title: 'Delete All Records?',
            text: 'This will remove all attendance records permanently!',
            icon: 'warning'
        }).then((result) => {
            if (result.isConfirmed) {
                $.ajax({
                    url: '../crud/delete_all_attendance.php',
                    method: 'POST',
                    success: function (response) {
                        const res = parseRes(response);
                        if (res.success) {
                            // clear() at hindi .empty(): pareho ang dahilan ng
                            // isahang delete sa itaas, mas malaki lamang ang
                            // epekto rito. Ang binabakante ng .empty() ay ang
                            // tbody; buo pa rin ang kopya ng DataTables, kaya
                            // ang buong talahanayang "binura" ay muling
                            // lumilitaw sa unang pag-click sa isang column
                            // header.
                            //
                            // May kapalit pa: sa clear() ay ang sariling
                            // "No data available in table" ng DataTables ang
                            // lumalabas. Sa .empty() ay puting bakanteng
                            // kahon — walang sinasabi kung nabura nga ba o
                            // nasira lang ang pahina.
                            $('#example tbody').fadeOut(300, function () {
                                // Wala nang natira, kaya pahina 1 —
                                // `true` ang pangalawang argumento.
                                table.ajax.reload(null, true);
                                // Ibinabalik ang display: naiwan itong
                                // display:none ng fadeOut, at ang tbody na ito
                                // rin ang pinupunan ng reload sa itaas.
                                $(this).show();
                                refreshSelectBar();
                            });
                            Swal.fire({
                                ...swalOptions,
                                icon: 'success',
                                title: 'Deleted!',
                                text: 'All attendance records have been cleared.',
                                timer: 1500,
                                showConfirmButton: false
                            });
                        } else {
                            Swal.fire({
                                ...swalOptions,
                                icon: 'error',
                                title: 'Error!',
                                text: 'Failed to delete all records.'
                            });
                        }
                    },
                    error: function () {
                        Swal.fire({
                            ...swalOptions,
                            icon: 'error',
                            title: 'Error!',
                            text: 'Something went wrong.'
                        });
                    }
                });
            }
        });
    });
});
