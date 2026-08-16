<?php
// ============================================================
// Ang tuntunin sa larawan ng estudyante, sa isang lugar.
//
// Dalawa ang pintuan papasok ng attendance: ang QR scanner
// (crud/save_attendance.php) at ang attendance link
// (crud/verify_student.php at crud/submit_attendance.php). Ang
// require_student_photo ay dating binabasa lamang ng scanner, kaya
// ang estudyanteng walang larawan ay hinaharang sa harap ng
// instruktor pero nakakapasok pa rin sa pamamagitan ng link — mas
// madali pang gamitin ang butas kaysa sa pintuang isinara.
//
// Ang dalawang tanong — "kailangan ba?" at "meron ba?" — ay narito
// lamang nang isang beses, para hindi na muling maghiwalay ang mga
// pintuan.
// ============================================================

/**
 * Naka-ON ba ang Settings > Student Photo Requirement?
 *
 * OFF ang sagot kapag wala pang hilera: bago ang setting kaysa sa
 * datos ng mga paaralang gumagamit na nito, at ang biglaang
 * pag-require ay hihinto sa attendance ng buong klase (tingnan ang
 * migrations/2026-08-10_add_require_student_photo_setting.sql).
 */
function photo_is_required(mysqli $conn): bool
{
    $res = $conn->query("
        SELECT setting_value
        FROM attendance_settings
        WHERE setting_key = 'require_student_photo'
        LIMIT 1
    ");

    if (!$res || $res->num_rows === 0) {
        return false;
    }

    return $res->fetch_assoc()['setting_value'] === '1';
}

/**
 * Wala bang larawan sa talaan ang student_no na ito?
 *
 * LEFT JOIN — ang estudyanteng walang hilera sa student_photos at
 * ang may hilerang blangko ang photo_path ay iisa ang ibig sabihin:
 * walang mukhang maipapakita.
 *
 * Totoo rin ang isinasauli kapag hindi umiiral ang student_no. Ang
 * mga tumatawag ay nauna nang sinuri kung umiiral ang estudyante,
 * kaya ang "walang nakita" ay hindi kailanman dapat ituring na may
 * larawan.
 */
function student_photo_missing(mysqli $conn, string $student_no): bool
{
    $stmt = $conn->prepare("
        SELECT p.photo_path
        FROM students_tbl s
        LEFT JOIN student_photos p ON p.s_id = s.id
        WHERE s.student_no = ?
        LIMIT 1
    ");
    $stmt->bind_param("s", $student_no);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return empty($row['photo_path']);
}

/**
 * Ang sasabihin sa estudyanteng hinarang ng tuntunin. Iisa ang
 * pananalita sa verify at sa submit — magkaibang hakbang, pero
 * iisang dahilan.
 */
function photo_required_message(): string
{
    return 'You need to upload your photo before you can record attendance. '
         . 'Open the Student Photo page, upload your picture, then try again.';
}
