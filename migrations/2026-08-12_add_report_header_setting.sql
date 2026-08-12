-- ============================================================
-- Palitan-able na header ng PDF reports (letterhead).
--
-- Bakit: nakasulat nang hardcoded sa loob ng dalawang export file
-- ang header — dalawang logo at ang teksto na "Binalatongan
-- Community College". Hindi ito mapapalitan ng admin, at magkaiba
-- pa ang dalawa: 'Binalatongan Community College' sa
-- exports/export_pdf.php, 'BINALATONGAN COMMUNITY COLLEGE' sa
-- exports/export_absences_pdf.php.
--
-- Ang report_header ay path ng isang malapad na banner (letterhead)
-- na ia-upload sa Settings > System Configuration. Kapag blangko,
-- babalik ang report sa dating dalawang-logo na layout — pero ang
-- pangalan ng paaralan ay galing na sa footer_org, hindi hardcoded.
--
-- Kailangan muna ang 2026-08-12_add_footer_settings.sql: doon
-- nagmumula ang footer_org na ginagamit bilang fallback na pangalan.
--
-- Ligtas i-rerun: IF NOT EXISTS ang ADD COLUMN.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-12_add_report_header_setting.sql
-- ============================================================

ALTER TABLE system_settings_tbl
    ADD COLUMN IF NOT EXISTS report_header VARCHAR(255) NOT NULL DEFAULT '' AFTER logo;

-- ── Tseke: dapat may report_header column na ─────────────────
SELECT logo, report_header, footer_org
FROM system_settings_tbl
WHERE id = 1;
