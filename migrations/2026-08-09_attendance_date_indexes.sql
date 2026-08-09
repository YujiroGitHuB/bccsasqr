-- ============================================================
-- Performance migration: suportahan ang date window ng attendance
--
-- Bakit: kumukuha na ngayon ang attendance.php ng isang saklaw
-- ng petsa sa halip na buong talahanayan:
--
--   admin      : WHERE date BETWEEN ? AND ?
--   instructor : WHERE user_id = ? AND date BETWEEN ? AND ?
--
-- Walang umiiral na index na sumasapol dito. Ang idx_section_date
-- ay (section, date) — hindi magagamit ang `date` kung walang
-- `section` sa WHERE. Ganoon din ang idx_user_section (user_id,
-- section) para sa branch ng instructor.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-09_attendance_date_indexes.sql
-- ============================================================

-- Para sa admin: pawang saklaw ng petsa.
ALTER TABLE attendance_tbl
    ADD KEY idx_date (date);

-- Para sa instructor: una ang user_id (pagkakapantay), tapos ang
-- date (saklaw) — iyon ang tamang pagkakasunod sa isang composite.
ALTER TABLE attendance_tbl
    ADD KEY idx_user_date (user_id, date);

-- ── Verify ───────────────────────────────────────────────────
-- Dapat "range" ang type at idx_date ang key, hindi "ALL".
EXPLAIN SELECT id, date, student_no, name, course, section, time_in, subject
FROM attendance_tbl
WHERE date BETWEEN '2026-07-10' AND '2026-08-09'
ORDER BY date DESC;
