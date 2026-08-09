-- ============================================================
-- Performance migration: index student_no lookups
--
-- Bakit: walang index ang students_tbl.student_no, kaya bawat QR
-- scan ay full table scan. Sa ~13k students, lumalaki ito nang
-- linear kaya mabagal sa production.
--
-- Ligtas i-rerun: normalize muna ang data bago mag-index, at
-- idempotent ang bawat ALTER (tingnan ang guard bago patakbuhin).
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-09_add_student_no_indexes.sql
-- ============================================================

-- ── 1. Pre-flight: dapat 0 ang lahat ng ito ─────────────────
-- Kung may lalabas na duplicate, ayusin muna bago tumuloy —
-- mabibigo ang UNIQUE KEY sa baba kung may dalawang magkaparehong
-- student_no.
SELECT student_no, COUNT(*) AS n
FROM students_tbl
GROUP BY student_no
HAVING COUNT(*) > 1;

-- ── 2. Normalize whitespace ─────────────────────────────────
-- Kailangan ito bago tanggalin ang TRIM() sa mga query. Kapag may
-- naiwang " 2021-1234" sa DB, hindi na ito matatagpuan ng plain
-- `WHERE student_no = ?` kapag na-drop na ang TRIM().
UPDATE students_tbl
SET student_no = TRIM(student_no)
WHERE student_no <> TRIM(student_no);

UPDATE student_subjects_tbl
SET student_no = TRIM(student_no)
WHERE student_no <> TRIM(student_no);

UPDATE student_subjects_tbl
SET subject_code = TRIM(subject_code)
WHERE subject_code <> TRIM(subject_code);

UPDATE attendance_tbl
SET student_no = TRIM(student_no)
WHERE student_no <> TRIM(student_no);

-- ── 3. Ang mismong index ────────────────────────────────────
-- UNIQUE dahil isang row lang dapat ang bawat student_no; nahuhuli
-- rin nito ang dobleng import sa hinaharap. Kung may kilalang
-- duplicate ka sa production na hindi pa kayang linisin, palitan
-- ng: ADD KEY idx_student_no (student_no)
ALTER TABLE students_tbl
    ADD UNIQUE KEY uniq_student_no (student_no);

-- Para sa LEFT JOIN users sa students list page.
ALTER TABLE students_tbl
    ADD KEY idx_user_id (user_id);

-- ── 4. Verify ───────────────────────────────────────────────
-- Dapat "ref" o "const" ang type, hindi "ALL".
EXPLAIN SELECT student_no, fullname, course, section
FROM students_tbl
WHERE student_no = '2021-0001';
