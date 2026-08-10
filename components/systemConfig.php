<!-- System Configuration Modal
     Anyo: assets/css/modal-form.css (klase: .app-modal) — pareho ng
     Add/Update Student. Ang tagapili ng logo ay nasa
     assets/css/settings-page.css (.cfg-*), dahil sa iisang modal
     lang ito ginagamit.

     Ang mga `id` at `name` ay hindi dapat baguhin — sila ang binabasa
     ng assets/js/systemConfig.js at ng crud/update_system_config.php. -->
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
                        <!-- Ito na ang tanging nagsasabi kung anong sistema ito sa
                             telepono: nakatago ang sidebar sa ≤992px at acronym lang
                             ang laman ng topbar doon (components/topBar.php). -->
                        <span class="app-hint" id="systemAcronymHint">The short form — sidebar, and the only label on phone screens. Keep it brief.</span>
                    </div>

                    <!-- System Logo -->
                    <div class="app-field">
                        <label for="systemLogo" class="form-label">System Logo</label>

                        <div class="cfg-logo">
                            <!-- Puting plate: karamihan ng logo ng paaralan ay
                                 madilim ang tinta at transparent ang background,
                                 kaya nawawala ang mga ito sa madilim na modal —
                                 at dito pa mismo tinitingnan ng admin kung tama
                                 ang na-upload niya. -->
                            <div class="cfg-plate<?= $systemLogo ? '' : ' is-empty' ?>" id="logoPreview">
                                <?php if ($systemLogo): ?>
                                    <img src="../<?= htmlspecialchars($systemLogo) ?>" alt="Current system logo">
                                <?php else: ?>
                                    <i class="bi bi-image" aria-hidden="true"></i>
                                <?php endif; ?>
                            </div>

                            <div class="cfg-logo-side">
                                <!-- Nakatago ang katutubong input pero naaabot pa rin
                                     ng keyboard (clip, hindi `display:none`) — ang
                                     "Choose File / No file chosen" ng browser ang
                                     tanging kontrol dito na hindi sumusunod sa anyo
                                     ng app, at hindi ito maistilo nang direkta. -->
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
                                    <!-- Walang paraan dating umatras sa napiling file
                                         maliban sa pagsara ng modal. -->
                                    <button type="button" class="cfg-undo" id="logoReset" hidden>
                                        <i class="bi bi-arrow-counterclockwise" aria-hidden="true"></i> Undo
                                    </button>
                                </div>

                                <span class="cfg-file-name is-idle" id="logoFileName">Keeping the current logo</span>
                                <!-- Ang tinatanggap lang ng crud/update_system_config.php
                                     ay ang apat na uri na sinusuri nito sa `getimagesize`. -->
                                <span class="app-hint" id="systemLogoHint">JPG, PNG, GIF, or WEBP. Square images sit best on the plate.</span>
                            </div>
                        </div>
                    </div>

                    <!-- Nasa loob ng <form> ang paanan para manatiling katutubo
                         ang pagsumite ng Save. -->
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
