-- ============================================================
-- Dynamic footer: ilipat sa database ang teksto ng footer.
--
-- Bakit: nakasulat nang hardcoded ang footer sa DALAWANG lugar —
-- components/footer.php (ginagamit ng sidebar, login, QR generator,
-- QR scanner, tracker, daily attendance, student photo profile) at
-- reg.php (may sariling kopya). Magkaiba pa ang pangalan ng
-- developer sa dalawa ("CNCCayading" laban sa "Charles Nixon C.
-- Cayading"). Ang pagpapalit ng pangalan ng paaralan o ng taon ay
-- nangangahulugan ng paghahanap sa buong repo.
--
-- Bakit BLANGKO ang default ng footer_year: kapag blangko, ang
-- kasalukuyang taon ang ipinapakita (date('Y')). Ang hardcoded na
-- "2025" ay luma na bago pa matapos ang unang taon nito — kaya
-- iwanang blangko maliban kung sadyang gusto mong i-freeze ang taon
-- (halimbawa "2023-2025").
--
-- Kapag blangko ang footer_developer_url, plain text na lang ang
-- pangalan ng developer — walang link.
--
-- Ligtas i-rerun: IF NOT EXISTS ang ADD COLUMN, at ang UPDATE ay
-- pinupunan lang ang mga blangkong halaga, kaya hindi nito
-- babaguhin ang na-edit mo na sa Settings.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-12_add_footer_settings.sql
-- ============================================================

ALTER TABLE system_settings_tbl
    ADD COLUMN IF NOT EXISTS footer_org           VARCHAR(255) NOT NULL DEFAULT '' AFTER logo,
    ADD COLUMN IF NOT EXISTS footer_year          VARCHAR(20)  NOT NULL DEFAULT '' AFTER footer_org,
    ADD COLUMN IF NOT EXISTS footer_developer     VARCHAR(255) NOT NULL DEFAULT '' AFTER footer_year,
    ADD COLUMN IF NOT EXISTS footer_developer_url VARCHAR(255) NOT NULL DEFAULT '' AFTER footer_developer;

-- Ang mga halagang ito ang eksaktong nasa hardcoded na footer bago
-- ang migration na ito, para walang pagbabagong makikita ang gumagamit
-- pagkatapos i-apply — maliban sa taon, na magiging kasalukuyan na.
UPDATE system_settings_tbl
SET footer_org           = 'Binalatongan Community College',
    footer_developer     = 'CNCCayading',
    footer_developer_url = 'https://cncc.vercel.app/'
WHERE id = 1
  AND footer_org = ''
  AND footer_developer = '';

-- ── Tseke: dapat may laman na ang apat na column ─────────────
SELECT footer_org, footer_year, footer_developer, footer_developer_url
FROM system_settings_tbl
WHERE id = 1;
