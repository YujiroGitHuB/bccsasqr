<div class="left-panel">
    <h2 style="display: flex; flex-direction: column; align-items: center; gap: 6px;">
        <!-- Collapsible Instructions with Icons -->
        <?php include __DIR__ . "/instruction_collapse.php" ?>
        <!-- header -->
        <img src="https://cdn-icons-gif.flaticon.com/7994/7994392.gif"
            alt="QR Animation"
            width="50"
            height="50"
            style="border-radius: 50%; object-fit: cover;">
        <?php echo $systemAcronym; ?> Code Generator
    </h2>
    <!-- form -->
    <label for="studentNo">Student Number (format: YEAR-Registration Number, e.g., 019-464 or 025-1023)</label>
    <!-- glitch input -->
    <?php include __DIR__ . "/glitch_input.php" ?>
    <div class="form-group">
        <label for="studentName">Full Name (Last First Middle)</label>
        <input readonly type="text" id="studentName" placeholder="e.g. Cayading, Charles Nixon C." />
    </div>

    <div class="form-group">
        <label for="course">Course (uppercase only)</label>
        <input readonly type="text" id="course" placeholder="e.g. BSIT" />
    </div>

    <div class="form-group">
        <label for="section">Section (format: 2A)</label>
        <input readonly type="text" id="section" placeholder="e.g. 3A" />
    </div>
    <!-- Terms and Conditions — kailangang tanggapin bago mabuksan
         ang Generate. Tingnan ang includes/terms.php para sa teksto. -->
    <div class="terms-agree" id="termsAgree">
        <label class="terms-check">
            <input type="checkbox" id="agreeTerms">
            <span>
                I agree to the
                <button type="button" class="terms-link" id="openTerms">Terms and Conditions</button>
            </span>
        </label>
    </div>

    <!-- generate button -->
    <?php include __DIR__ . "/button_generate.php" ?>
</div>

<!-- Terms Modal -->
<div class="terms-modal" id="termsModal" role="dialog" aria-modal="true" aria-labelledby="termsTitle">
    <div class="terms-modal-content">
        <div class="terms-modal-header">
            <h3 id="termsTitle"><i class="bi bi-file-earmark-text"></i> Terms and Conditions</h3>
            <button type="button" class="terms-close" id="closeTerms" aria-label="Close">&times;</button>
        </div>
        <div class="terms-modal-body">
            <?php
            require_once __DIR__ . "/../../includes/terms.php";
            echo terms_body_html();
            ?>
        </div>
        <div class="terms-modal-footer">
            <button type="button" class="terms-btn terms-btn-ghost" id="termsClose2">Close</button>
            <button type="button" class="terms-btn terms-btn-primary" id="termsAccept">
                I Agree
            </button>
        </div>
    </div>
</div>