-- ============================================================
-- Tinatanggal ang room code at ang selfie spot check.
--
-- Tatlong tampok ang isinama ng
-- migrations/2026-09-09_add_attendance_integrity.sql. Dalawa sa
-- kanila ay hinigit pabalik bago pa magamit sa klase:
--
--   room code   — anim na digit sa harapan ng silid. Nangangailangan
--                 ng projector o pisara sa bawat klase, at ng isang
--                 instruktor na may nakabukas na screen sa buong
--                 oras. Sobrang bigat para sa nadadagdag nito.
--
--   selfie      — tumatawag ng camera, kailangan ng permission ng
--                 estudyante, at bumibigat sa isang libreng hosting.
--
-- Ang natira ay ang isang tsekeng walang kapalit na abala para sa
-- estudyante: isang device, isang estudyante kada link kada araw.
-- Hindi siya tumitipa ng kahit ano at walang hinihintay — nagsusumite
-- lang siya gaya ng dati, at ang cookie ang sumasagot.
--
-- HINDI ito humahawak ng attendance_audit_tbl o ng
-- attendance_ratelimit_tbl: nananatili ang dalawa, at ang device
-- binding ang gumagamit ng mga ito.
--
-- Ligtas i-rerun, at ligtas ding patakbuhin sa database na hindi pa
-- nakakapagtakbo ng unang migration: IF EXISTS ang lahat.
--
-- Patakbuhin PAGKATAPOS ng 2026-09-09_add_attendance_integrity.sql:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-09-09b_drop_room_code_and_selfie.sql
-- ============================================================


-- ── 1. Ang binhi at ang switch ng room code ─────────────────
--
-- Walang ibang bumabasa ng dalawang column na ito ngayon. Ang binhi
-- ang mas mahalagang tanggalin sa dalawa: HMAC key iyon na
-- nakahiga sa isang talaang bina-back up at ini-export.
--
-- Walang bantay sa TALAHANAYAN dito, at hindi kailangan: ang
-- attendance_links_tbl ay bahagi ng batayang schema at laging
-- nariyan. Ang DROP COLUMN IF EXISTS ang bumabantay sa column.
ALTER TABLE attendance_links_tbl
    DROP COLUMN IF EXISTS require_room_code,
    DROP COLUMN IF EXISTS room_code_secret;


-- ── 2. Ang attendance_audit_tbl ─────────────────────────────
--
-- Dalawang bagay: ang column na selfie_path, at ang mga hilerang
-- 'bad_room_code' na hindi na kailanman muling isusulat.
--
-- Bakit ganito ang anyo, at hindi ALTER TABLE nang diretso: ang
-- talaang ito ay dumarating kasama ng UNANG migration. Sa database
-- na hindi pa iyon napapatakbo, ang isang ALTER dito ay pumapatay
-- sa buong file sa gitna — at kalahating naipatupad na migration
-- ang pinakamasamang kalagayan.
--
-- Ang DROP COLUMN IF EXISTS ay hindi sapat: ang IF EXISTS doon ay
-- bumabantay sa COLUMN, hindi sa TALAHANAYAN. Wala ring
-- "ALTER TABLE IF EXISTS" sa MariaDB 10.4. Kaya itinatanong muna
-- kung nariyan ang talaan, at kapag wala ay DO 0 — walang
-- ginagawa, walang error.
SET @has_audit = (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = DATABASE() AND table_name = 'attendance_audit_tbl'
);

SET @sql = IF(@has_audit > 0,
    'ALTER TABLE attendance_audit_tbl DROP COLUMN IF EXISTS selfie_path',
    'DO 0');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

-- Ang mga hilerang 'ok' at 'device_reuse' ay hindi ginagalaw:
-- ebidensya pa rin sila.
SET @sql = IF(@has_audit > 0,
    'DELETE FROM attendance_audit_tbl WHERE result = ''bad_room_code''',
    'DO 0');
PREPARE s2 FROM @sql; EXECUTE s2; DEALLOCATE PREPARE s2;


-- ── 3. Ang setting ──────────────────────────────────────────
--
-- Wala nang bumabasa ng selfie_spot_rate. Ang device_binding ay
-- NANANATILI — iyon ang tampok na natira.
DELETE FROM attendance_settings WHERE setting_key = 'selfie_spot_rate';


-- ── Tseke ───────────────────────────────────────────────────
SELECT setting_key, setting_value FROM attendance_settings
WHERE setting_key IN ('device_binding', 'selfie_spot_rate', 'require_student_photo', 'form_locked');

SELECT column_name FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND ((table_name = 'attendance_links_tbl' AND column_name IN ('require_room_code', 'room_code_secret'))
    OR (table_name = 'attendance_audit_tbl' AND column_name = 'selfie_path'));
-- Walang hilerang lumabas sa itaas = tapos na ang paglilinis.
