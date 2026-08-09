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
    <!-- generate button -->
    <?php include __DIR__ . "/button_generate.php" ?>
</div>