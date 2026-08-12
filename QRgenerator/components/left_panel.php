<div class="left-panel">
    <h2 class="panel-title"><i class="bi bi-person-vcard"></i> Your Details</h2>

    <!-- Collapsible Instructions -->
    <?php include __DIR__ . "/instruction_collapse.php" ?>

    <!-- The only typed field -->
    <?php include __DIR__ . "/glitch_input.php" ?>

    <!-- From the record, not typed. fetch_students.js adds `is-filled`
         once verification succeeds. -->
    <div class="locked-fields" id="lockedFields">
        <div class="locked-row">
            <label class="field-label" for="studentName">Name</label>
            <div class="locked-input">
                <i class="bi bi-lock-fill locked-icon" aria-hidden="true"></i>
                <input readonly type="text" id="studentName" tabindex="-1" placeholder="—" />
            </div>
        </div>

        <div class="locked-row">
            <label class="field-label" for="course">Course</label>
            <div class="locked-input">
                <i class="bi bi-lock-fill locked-icon" aria-hidden="true"></i>
                <input readonly type="text" id="course" tabindex="-1" placeholder="—" />
            </div>
        </div>

        <div class="locked-row">
            <label class="field-label" for="section">Section</label>
            <div class="locked-input">
                <i class="bi bi-lock-fill locked-icon" aria-hidden="true"></i>
                <input readonly type="text" id="section" tabindex="-1" placeholder="—" />
            </div>
        </div>
    </div>

    <!-- Terms and Conditions — must be accepted before Generate
         unlocks. See includes/terms.php for the text. -->
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
