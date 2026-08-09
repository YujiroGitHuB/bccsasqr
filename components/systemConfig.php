            <!-- System Configuration Modal -->
            <div class="modal fade" id="systemConfigModal" tabindex="-1" aria-labelledby="systemConfigModalLabel" aria-hidden="true">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                    <div class="modal-content shadow-lg rounded-4 border-0">
                        <form id="systemConfigForm" enctype="multipart/form-data">
                            <div class="modal-header border-0 pb-0">
                                <h5 class="modal-title fw-bold" id="systemConfigModalLabel">
                                    <i class="bi bi-gear-fill me-2"></i>Update System Configuration
                                </h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                            </div>

                            <div class="modal-body pt-0">
                                <!-- System Name -->
                                <div class="mb-4">
                                    <label for="systemName" class="form-label fw-semibold">System Name</label>
                                    <input type="text" class="form-control form-control-lg shadow-sm rounded-3"
                                        id="systemName" name="systemName" value="<?= htmlspecialchars($systemName) ?>" required>
                                </div>

                                <!-- System Acronym -->
                                <div class="mb-4">
                                    <label for="systemAcronym" class="form-label fw-semibold">System Acronym</label>
                                    <input type="text" class="form-control form-control-lg shadow-sm rounded-3"
                                        id="systemAcronym" name="systemAcronym" value="<?= htmlspecialchars($systemAcronym) ?>" required>
                                </div>

                                <!-- Logo Preview -->
                                <div id="logoPreview" class="mb-3 d-flex justify-content-center">
                                    <?php if ($systemLogo): ?>
                                        <div class="card border-0 shadow-sm rounded-3 p-2" style="width:120px; height:120px; display:flex; align-items:center; justify-content:center;">
                                            <img src="../<?= $systemLogo ?>" alt="Logo Preview" class="img-fluid rounded-3">
                                        </div>
                                    <?php else: ?>
                                        <div class="text-muted">No logo uploaded</div>
                                    <?php endif; ?>
                                </div>

                                <!-- System Logo -->
                                <div class="mb-4">
                                    <label for="systemLogo" class="form-label fw-semibold">System Logo</label>
                                    <input type="file" class="form-control form-control-lg shadow-sm rounded-3"
                                        id="systemLogo" name="systemLogo" accept="image/*">
                                    <small class="form-text text-muted">Upload a new logo to replace the current one.</small>
                                </div>
                            </div>
                            <div class="modal-footer border-0 pt-0">
                                <button type="button" class="btn btn-outline-secondary rounded-3" data-bs-dismiss="modal">Cancel</button>
                                <button type="submit" class="btn btn-primary rounded-3 px-4 shadow-sm">Save Changes</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>