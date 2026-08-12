<!-- System Configuration Modal
     Styling: assets/css/modal-form.css (class: .app-modal) — same as
     Add/Update Student. The logo picker lives in
     assets/css/settings-page.css (.cfg-*), because only this one
     modal uses it.

     The `id`s and `name`s must not change — they are what
     assets/js/systemConfig.js and crud/update_system_config.php
     read. -->
<div class="modal fade app-modal" id="systemConfigModal" tabindex="-1" aria-labelledby="systemConfigModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">

            <div class="modal-header">
                <div class="app-modal-icon"><i class="bi bi-sliders"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="systemConfigModalLabel">System Configuration</h5>
                    <p>The identity shown across the sidebar, tab, and reports.</p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <div class="modal-body">
                <form id="systemConfigForm" enctype="multipart/form-data">

                    <!-- System Name -->
                    <div class="app-field">
                        <label for="systemName" class="form-label">System Name</label>
                        <div class="app-input">
                            <i class="bi bi-card-heading" aria-hidden="true"></i>
                            <input type="text"
                                class="form-control"
                                id="systemName"
                                name="systemName"
                                value="<?= htmlspecialchars($systemName) ?>"
                                placeholder="BCC Student Attendance System Using QR"
                                autocomplete="off"
                                aria-describedby="systemNameHint"
                                required>
                        </div>
                        <span class="app-hint" id="systemNameHint">The full name — browser tab and the header of exported reports.</span>
                    </div>

                    <!-- System Acronym -->
                    <div class="app-field">
                        <label for="systemAcronym" class="form-label">System Acronym</label>
                        <div class="app-input">
                            <i class="bi bi-type" aria-hidden="true"></i>
                            <input type="text"
                                class="form-control"
                                id="systemAcronym"
                                name="systemAcronym"
                                value="<?= htmlspecialchars($systemAcronym) ?>"
                                placeholder="BCC SASQR v1.0"
                                autocomplete="off"
                                aria-describedby="systemAcronymHint"
                                required>
                        </div>
                        <!-- On a phone this is the only thing that says which
                             system this is: the sidebar is hidden at ≤992px and
                             the topbar carries only the acronym there
                             (components/topBar.php). -->
                        <span class="app-hint" id="systemAcronymHint">The short form — sidebar, and the only label on phone screens. Keep it brief.</span>
                    </div>

                    <!-- System Logo -->
                    <div class="app-field">
                        <label for="systemLogo" class="form-label">System Logo</label>

                        <div class="cfg-logo">
                            <!-- White plate: most school logos are dark ink on a
                                 transparent background, so they disappear into
                                 the dark modal — and this is exactly where an
                                 admin checks that the right thing was
                                 uploaded. -->
                            <div class="cfg-plate<?= $systemLogo ? '' : ' is-empty' ?>" id="logoPreview">
                                <?php if ($systemLogo): ?>
                                    <img src="../<?= htmlspecialchars($systemLogo) ?>" alt="Current system logo">
                                <?php else: ?>
                                    <i class="bi bi-image" aria-hidden="true"></i>
                                <?php endif; ?>
                            </div>

                            <div class="cfg-logo-side">
                                <!-- The native input is hidden but still reachable by
                                     keyboard (clipped, not `display:none`) — the
                                     browser's "Choose File / No file chosen" is the
                                     only control here that does not follow the app's
                                     styling, and it cannot be styled directly. -->
                                <input type="file"
                                    class="cfg-file"
                                    id="systemLogo"
                                    name="systemLogo"
                                    accept="image/jpeg,image/png,image/gif,image/webp"
                                    aria-describedby="systemLogoHint">

                                <div class="cfg-logo-actions">
                                    <label for="systemLogo" class="app-btn ghost cfg-pick">
                                        <i class="bi bi-upload" aria-hidden="true"></i> Choose image
                                    </label>
                                    <!-- There used to be no way back from a chosen
                                         file except closing the modal. -->
                                    <button type="button" class="cfg-undo" id="logoReset" hidden>
                                        <i class="bi bi-arrow-counterclockwise" aria-hidden="true"></i> Undo
                                    </button>
                                </div>

                                <span class="cfg-file-name is-idle" id="logoFileName">Keeping the current logo</span>
                                <!-- crud/update_system_config.php accepts only the four
                                     types it checks with `getimagesize`. -->
                                <span class="app-hint" id="systemLogoHint">JPG, PNG, GIF, or WEBP. Square images sit best on the plate.</span>
                            </div>
                        </div>
                    </div>

                    <!-- The footer sits inside the <form> so Save submits
                         natively. -->
                    <div class="app-modal-footer">
                        <button type="button" class="app-btn ghost" data-bs-dismiss="modal">Cancel</button>
                        <button type="submit" class="app-btn primary">
                            <i class="bi bi-check-circle-fill" aria-hidden="true"></i> Save Changes
                        </button>
                    </div>
                </form>
            </div>

        </div>
    </div>
</div>
