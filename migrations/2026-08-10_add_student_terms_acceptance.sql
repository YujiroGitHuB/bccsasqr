-- ============================================================
-- Talaan ng pagtanggap sa Terms and Conditions ng estudyante
--
-- Bakit: bago mag-generate ng sariling QR, kailangang tanggapin ng
-- estudyante ang mga tuntunin — kasama na ang paalala na personal
-- ang QR at hindi dapat ipahiram. Kinokolekta rin ng sistema ang
-- pangalan, kurso, seksyon, oras ng pagpasok, at (kung mayroon)
-- larawan ng estudyante, kaya may abiso rin sa datos.
--
-- Itinatala natin ito para may patunay ang paaralan ng pahintulot,
-- at hindi lang sa browser ng estudyante — nawawala iyon kapag
-- lumipat siya ng device o nilinis ang browser.
--
-- Ang terms_version ay para kapag binago ang teksto: itaas ang
-- TERMS_VERSION sa includes/terms.php at muling tatanungin ang
-- lahat, habang nananatili ang lumang talaan bilang kasaysayan.
--
-- Ligtas i-rerun: may IF NOT EXISTS ang CREATE TABLE.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-10_add_student_terms_acceptance.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS student_terms_tbl (
    id            INT(11)      NOT NULL AUTO_INCREMENT,
    student_no    VARCHAR(50)  NOT NULL,
    terms_version INT(11)      NOT NULL DEFAULT 1,
    accepted_at   TIMESTAMP    NOT NULL DEFAULT current_timestamp(),

    -- Pantulong sa pag-imbestiga kapag may pinagtatalunang talaan.
    -- Hindi ito ginagamit para sa iba pa.
    ip_address    VARCHAR(45)  DEFAULT NULL,

    PRIMARY KEY (id),

    -- Isang talaan kada estudyante kada bersyon. Kapag pinindot
    -- niyang muli ang pagtanggap, ina-update lang ang oras — hindi
    -- nagdaragdag ng bagong row.
    UNIQUE KEY uniq_student_version (student_no, terms_version),

    KEY idx_student_no (student_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ── Tseke ───────────────────────────────────────────────────
SHOW CREATE TABLE student_terms_tbl;
