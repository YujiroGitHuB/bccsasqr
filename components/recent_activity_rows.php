<?php
/**
 * The rows inside the dashboard's "Recent Activity" panel.
 *
 * Its own file because two callers render it: the dashboard on a full
 * page load, and the 30-second refresh in the same file, which asks
 * for `?ajax=recent` and drops the answer straight into the panel. A
 * second copy of this markup would drift from the first the moment
 * either changed.
 *
 * Expects:
 *   $recentLogs  mysqli_result|null  rows with student_no, name, course,
 *                                    section, subject, time_in,
 *                                    instructor_name, photo_path
 *   $activityIsToday  bool           only changes the empty-state wording
 */
$activityIsToday = $activityIsToday ?? true;
?>
<?php if ($recentLogs && $recentLogs->num_rows > 0): ?>
    <?php while ($row = $recentLogs->fetch_assoc()): ?>
        <div class="dash-act-row">
            <div class="dash-act-avatar">
                <?php // The initial stays underneath: `onerror` drops the <img>
                      // when the file is gone, so a stale row in student_photos
                      // degrades to the letter instead of a broken-image icon.
                ?>
                <?php if (!empty($row['photo_path'])): ?>
                    <img src="../<?= htmlspecialchars($row['photo_path']) ?>"
                         alt="<?= htmlspecialchars($row['name']) ?>"
                         loading="lazy" decoding="async"
                         onerror="this.remove()">
                <?php endif; ?>
                <?= htmlspecialchars(strtoupper(substr($row['name'], 0, 1))) ?>
            </div>
            <div class="dash-act-main">
                <strong><?= htmlspecialchars($row['name']) ?></strong>
                <div class="dash-act-meta">
                    <span><?= htmlspecialchars($row['student_no']) ?></span>
                    <span>·</span>
                    <span><?= htmlspecialchars($row['course'] . '-' . $row['section']) ?></span>
                    <?php if ($row['subject']): ?>
                        <span class="subj"><?= htmlspecialchars($row['subject']) ?></span>
                    <?php endif; ?>
                    <?php if ($row['instructor_name']): ?>
                        <span>·</span>
                        <span><i class="bi bi-person-badge"></i>
                            <?= htmlspecialchars($row['instructor_name']) ?></span>
                    <?php endif; ?>
                </div>
            </div>
            <span class="dash-act-time">
                <i class="bi bi-clock"></i>
                <?= date("g:i A", strtotime($row['time_in'])) ?>
            </span>
        </div>
    <?php endwhile; ?>
<?php else: ?>
    <div class="dash-empty">
        <i class="bi bi-inbox"></i>
        <strong>No activity <?= $activityIsToday ? 'yet' : 'on this date' ?></strong>
        <span>
            <?= $activityIsToday
                ? 'Scans will appear here once students take attendance.'
                : 'Nobody scanned within your subjects or sections on the selected date.' ?>
        </span>
    </div>
<?php endif; ?>
