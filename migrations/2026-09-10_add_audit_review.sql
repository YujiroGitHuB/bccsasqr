-- ============================================================
-- Ang natuklasan ay kailangang may kahihinatnan.
--
-- Ang pages/attendance_integrity.php ay nagpapakita ng anim na
-- 'device_reuse' at doon nagtatapos. Walang paraan para sabihing
-- "tiningnan ko na ito", walang mailalagay na dahilan, at walang
-- nakikita ang kapwa guro kapag siya naman ang tumingin bukas. Kaya
-- ang parehong anim ay muling sinusuri kada linggo, at ang totoong
-- bago ay nalulunod sa mga lumang nasagot na.
--
-- Tatlong column ang idinadagdag nito sa attendance_audit_tbl, at
-- tatlong index na kulang mula noong 2026-09-09.
--
-- Ligtas i-rerun: IF NOT EXISTS ang lahat, at binabantayan ang
-- pag-iral ng talahanayan bago hawakan.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-09-10_add_audit_review.sql
-- ============================================================


-- Kagaya ng 2026-09-09b: ang IF NOT EXISTS sa ADD COLUMN ay
-- bumabantay sa COLUMN at hindi sa TALAHANAYAN, at walang
-- "ALTER TABLE IF EXISTS" sa MariaDB 10.4. Kaya itinatanong muna.
SET @has_audit = (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = DATABASE() AND table_name = 'attendance_audit_tbl'
);


-- ── 1. Ang pagsusuri ────────────────────────────────────────
--
-- reviewed_at  kailan ito tiningnan. NULL = hindi pa.
-- reviewed_by  sino. users_tbl.id — walang FOREIGN KEY, gaya ng
--              instructor_id sa parehong talahanayan: ang tinanggal
--              na guro ay hindi dapat magbura ng ebidensya.
-- note         ang dahilan, sa mga salita ng gurong tumingin.
--              "Hiniram ang telepono, kinumpirma ko" ay ang buong
--              silbi ng talaang ito — ang bahaging hindi kayang
--              hulaan ng makina.
--
-- VARCHAR(255) at hindi TEXT: sampung megabyte lamang ang database,
-- at ang tala ay pangungusap, hindi sanaysay.
SET @sql = IF(@has_audit > 0,
    'ALTER TABLE attendance_audit_tbl
        ADD COLUMN IF NOT EXISTS reviewed_at DATETIME     NULL DEFAULT NULL AFTER result,
        ADD COLUMN IF NOT EXISTS reviewed_by INT(11)      NULL DEFAULT NULL AFTER reviewed_at,
        ADD COLUMN IF NOT EXISTS note        VARCHAR(255) NULL DEFAULT NULL AFTER reviewed_by',
    'DO 0');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;


-- ── 2. Ang mga index na kulang ──────────────────────────────
--
-- Tatlong bagong tanong ang natutunan ng pahina mula noong ginawa
-- ang talahanayan, at wala ni isa sa mga ito ang may index:
--
--   idx_scope     ang instruktor ay nakikita ang sarili niyang klase
--                 lamang — nasa BAWAT tanong ng pahina ang salaang
--                 ito, kaya ito ang pinakamahalaga sa tatlo
--   idx_link      ang bagong pagpili ng klase
--   idx_reviewed  "ano ang hindi ko pa natitingnan"
--
-- Kasama ang created_at sa dalawa: laging may saklaw ng panahon ang
-- tanong, kaya ang index na tumatapos sa petsa ay sumasagot ng buo.
SET @sql = IF(@has_audit > 0,
    'ALTER TABLE attendance_audit_tbl
        ADD INDEX IF NOT EXISTS idx_scope    (instructor_id, created_at),
        ADD INDEX IF NOT EXISTS idx_link     (short_code, created_at),
        ADD INDEX IF NOT EXISTS idx_reviewed (reviewed_at)',
    'DO 0');
PREPARE s2 FROM @sql; EXECUTE s2; DEALLOCATE PREPARE s2;


-- ── Tseke ───────────────────────────────────────────────────
-- Tatlong column at tatlong index ang dapat lumabas.
SELECT column_name FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name   = 'attendance_audit_tbl'
  AND column_name IN ('reviewed_at', 'reviewed_by', 'note');

SELECT DISTINCT index_name FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name   = 'attendance_audit_tbl'
  AND index_name IN ('idx_scope', 'idx_link', 'idx_reviewed');
