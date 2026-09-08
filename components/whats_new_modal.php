<?php
/*
 * "What's New" modal — the release timeline.
 *
 * Included once per admin page by includes/footer.php, so no page
 * has to know about it. The content comes from
 * includes/whats_new.php; nothing here is hardcoded except the
 * shape.
 *
 * Styling: assets/css/modal-form.css (.app-modal, the house style)
 * plus assets/css/whats-new.css (.wn-*, the timeline).
 * Behaviour: assets/js/whatsNew.js — it reads the version out of the
 * data-version attribute below, so the seen-marker cannot drift from
 * the changelog.
 */
require_once __DIR__ . '/../includes/whats_new.php';

$__wnReleases = whats_new_releases();
?>
<div class="modal fade app-modal wn-modal" id="whatsNewModal" tabindex="-1"
     aria-labelledby="whatsNewModalLabel" aria-hidden="true"
     data-version="<?php echo htmlspecialchars(WHATS_NEW_VERSION); ?>">
    <div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">
        <div class="modal-content">

            <div class="modal-header">
                <div class="app-modal-icon"><i class="bi bi-stars"></i></div>
                <div class="app-modal-heading">
                    <h5 class="modal-title" id="whatsNewModalLabel">What&rsquo;s New</h5>
                    <p>Everything added to <?php echo htmlspecialchars($systemAcronym ?? 'the system'); ?>, newest first</p>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <div class="modal-body">
                <?php if (!$__wnReleases) { ?>

                    <!-- Only reachable if whats_new_releases() is emptied.
                         Better an honest empty state than a bare modal. -->
                    <div class="app-state">
                        <div class="app-state-icon"><i class="bi bi-journal-text"></i></div>
                        <h6>Nothing logged yet</h6>
                        <p>Releases will appear here as they ship.</p>
                    </div>

                <?php } else { ?>

                    <!-- <ol>, not <div>: this is an ordered sequence of
                         releases, and a screen reader should be able to
                         say how many there are and which one it is on. -->
                    <ol class="wn-timeline">
                        <?php foreach ($__wnReleases as $__i => $__rel) {
                            // The newest entry carries the live dot and the
                            // "Latest" chip. Position, not a flag in the
                            // data — the array is ordered, so the first
                            // one IS the latest and cannot fall out of step.
                            $__latest = ($__i === 0);
                            $__ts     = strtotime($__rel['date']);
                            ?>
                            <li class="wn-release<?php echo $__latest ? ' is-latest' : ''; ?>">

                                <span class="wn-node" aria-hidden="true">
                                    <i class="bi <?php echo htmlspecialchars($__rel['icon']); ?>"></i>
                                </span>

                                <div class="wn-head">
                                    <!-- datetime= keeps the machine-readable
                                         date even though the label is the
                                         friendlier one. -->
                                    <time class="wn-date" datetime="<?php echo htmlspecialchars($__rel['date']); ?>">
                                        <?php echo $__ts ? date('M j, Y', $__ts) : htmlspecialchars($__rel['date']); ?>
                                    </time>
                                    <?php if ($__latest) { ?>
                                        <span class="wn-latest">Latest</span>
                                    <?php } ?>
                                </div>

                                <h6 class="wn-title"><?php echo htmlspecialchars($__rel['title']); ?></h6>
                                <?php if (!empty($__rel['summary'])) { ?>
                                    <p class="wn-summary"><?php echo htmlspecialchars($__rel['summary']); ?></p>
                                <?php } ?>

                                <ul class="wn-items">
                                    <?php foreach ($__rel['items'] as $__item) {
                                        list($__label, $__cls) = whats_new_tag($__item['type']);
                                        ?>
                                        <li class="wn-item">
                                            <span class="wn-item-icon" aria-hidden="true">
                                                <i class="bi <?php echo htmlspecialchars($__item['icon']); ?>"></i>
                                            </span>
                                            <div class="wn-item-body">
                                                <div class="wn-item-head">
                                                    <strong><?php echo htmlspecialchars($__item['title']); ?></strong>
                                                    <span class="wn-tag <?php echo $__cls; ?>"><?php echo htmlspecialchars($__label); ?></span>
                                                </div>
                                                <?php // Authored in includes/whats_new.php, not user input — see the note there. ?>
                                                <p><?php echo $__item['text']; ?></p>
                                            </div>
                                        </li>
                                    <?php } ?>
                                </ul>
                            </li>
                        <?php } ?>
                    </ol>

                    <p class="wn-end">
                        <i class="bi bi-flag" aria-hidden="true"></i>
                        That&rsquo;s as far back as the log goes.
                    </p>

                <?php } ?>
            </div>

            <div class="modal-footer">
                <button type="button" class="app-btn primary" data-bs-dismiss="modal">
                    <i class="bi bi-check2"></i> Got it
                </button>
            </div>

        </div>
    </div>
</div>
