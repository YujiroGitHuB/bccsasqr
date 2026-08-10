-- ============================================================
-- Bagong setting: "Require student photo for scanning"
--
-- Bakit: ang photo ng estudyante ang tanging biswal na patunay ng
-- pagkakakilanlan sa QR scanner. Kung walang mukhang lumalabas,
-- puwedeng i-screenshot o ipahiram ang QR at walang makakahuli —
-- proxy attendance.
--
-- Bakit naka-OFF ang default: kapag marami pang estudyante ang
-- walang na-upload na photo, ang biglaang pag-require ay hihinto
-- sa attendance ng buong klase, at ang estudyante pa ang
-- naparurusahan sa kakulangan sa datos na hindi niya kasalanan.
-- Habang OFF, pumapasa ang scan pero may malinaw na babala sa
-- scanner na hindi ma-verify ang pagkakakilanlan.
--
-- Kapag sapat na ang photo coverage, i-ON ito mula sa
-- Settings > Student Photo Requirement.
--
-- Ligtas i-rerun: INSERT IGNORE at may UNIQUE KEY ang setting_key,
-- kaya hindi nababago ang halaga kung naitakda mo na ito.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-10_add_require_student_photo_setting.sql
-- ============================================================

INSERT IGNORE INTO attendance_settings (setting_key, setting_value, updated_at)
VALUES ('require_student_photo', '0', NOW());

-- ── Tseke: dapat may isang row na ang halaga ay 0 o 1 ────────
SELECT setting_key, setting_value, updated_at
FROM attendance_settings
WHERE setting_key = 'require_student_photo';
