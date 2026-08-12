<?php
/* The page's only typed field.

   This used to be a "holo/glitch" input: fixed at 270px inside a
   wrapper with 1.5rem of padding, so it never lined up with the
   other fields; it had a color family of its own (cyan #00f2ea +
   violet #a855f7) and its own typeface (Fira Code) found nowhere
   else in the app; and its label pointed at `for="holo-input"` — an
   id that does not exist on the page, so no label was associated
   with the real box at all.

   The file name is kept so the includes in left_panel.php do not
   have to change. */
?>
<div class="qr-field qr-field-primary" id="studentNoField">
    <label for="studentNo">
        Student Number
        <span class="field-hint">Format: YEAR-Registration No. — e.g. 019-464 or 025-1023</span>
    </label>

    <input
        type="text"
        id="studentNo"
        name="studentNo"
        inputmode="numeric"
        autocomplete="off"
        spellcheck="false"
        placeholder="019-464"
        aria-describedby="studentStatus"
        required />

    <!-- fetch_students.js writes the lookup result here. `aria-live`
         so it reaches a screen reader too — this used to be a silent
         box that the eye could see but nobody could hear. -->
    <div class="qr-status" id="studentStatus" role="status" aria-live="polite"></div>
</div>
