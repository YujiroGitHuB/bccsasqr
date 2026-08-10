<?php
/* Ang tanging tinitipahang patlang ng pahina.

   Dating "holo/glitch" na input ito: naka-fixed sa 270px sa loob
   ng wrapper na may 1.5rem na padding, kaya hindi kailanman
   pumipila sa ibang patlang; may sarili itong pamilya ng kulay
   (cyan #00f2ea + lila #a855f7) at sariling tipo ng letra (Fira
   Code) na wala sa ibang bahagi ng app; at ang label nito ay
   nakaturo sa `for="holo-input"` — isang id na wala sa pahina,
   kaya walang label na naiuugnay sa totoong kahon.

   Ang pangalan ng file ay pinanatili para hindi na baguhin ang mga
   include sa left_panel.php. */
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

    <!-- Dito isinusulat ng fetch_students.js ang resulta ng
         paghahanap. `aria-live` para maiparating din ito sa screen
         reader — dating tahimik na kahon lang ito na nakikita ng
         mata pero hindi naririnig. -->
    <div class="qr-status" id="studentStatus" role="status" aria-live="polite"></div>
</div>
