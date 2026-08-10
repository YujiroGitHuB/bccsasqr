<?php
/*
 * ============================================================
 * Terms and Conditions para sa QR generation ng estudyante
 *
 * BABALA SA NAGMAMAY-ARI: DRAFT ang teksto sa ibaba. Ipabasa ito
 * sa administrasyon ng paaralan (at sa Data Protection Officer, kung
 * mayroon) bago gamitin sa production. Hindi ito legal na payo — mga
 * karaniwang tuntunin lang ito na akma sa ginagawa ng sistema.
 *
 * Palitan ang CONTACT_EMAIL sa ibaba ng totoong opisina.
 *
 * Kapag binago mo ang teksto, ITAAS ang TERMS_VERSION. Muling
 * tatanungin ang lahat ng estudyante, at mananatili ang lumang
 * talaan sa student_terms_tbl bilang kasaysayan.
 * ============================================================
 */

// Itaas kapag may makabuluhang pagbabago sa teksto sa ibaba.
const TERMS_VERSION = 1;

// Palitan ng totoong opisina/email ng paaralan.
const TERMS_CONTACT = 'charlesnixoncayading@gmail.com';

function terms_body_html(): string
{
    $contact = htmlspecialchars(TERMS_CONTACT);

    return <<<HTML
<h4>1. Your QR code is personal</h4>
<p>
    The QR code generated here identifies you and you alone. Do not share it,
    send it to anyone, or let another person present it on your behalf.
</p>

<h4>2. Letting someone else use your QR is academic dishonesty</h4>
<p>
    Presenting another student's QR code, or asking someone to present yours so
    you can be marked present while absent, is a form of academic dishonesty and
    may be dealt with under the school's existing student discipline rules.
</p>

<h4>3. What the system records</h4>
<p>
    When your QR code is scanned, the system records your student number, full
    name, course, section, the subject, and the date and time of the scan. If
    your photo has been uploaded by the school, it is shown to your instructor
    at the moment of scanning so they can confirm your identity.
</p>

<h4>4. Why it is collected</h4>
<p>
    This information is used only to record and verify class attendance, and to
    produce attendance reports for your instructors and the school. It is not
    sold, and it is not shared with anyone outside the school except where the
    school is required to do so.
</p>

<h4>5. Who can see it</h4>
<p>
    Your attendance records can be seen by the instructors of the subjects you
    are enrolled in, and by school administrators of this system.
</p>

<h4>6. Corrections and questions</h4>
<p>
    If your details are wrong, if an attendance record looks incorrect, or if
    you have questions about how your information is handled, contact
    <strong>{$contact}</strong>.
</p>

<h4>7. Keep your QR safe</h4>
<p>
    Treat your QR code like your ID. If you believe someone else has a copy of
    it, generate a new one and inform your instructor.
</p>
HTML;
}
