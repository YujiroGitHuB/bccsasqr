-- ============================================================
-- Scans the app kept while it had no internet.
--
-- The app's scanner keeps a scan on the phone when the server cannot
-- be reached and sends it later (POST /api/v1/scanner/sync). Its date
-- and time_in are then the phone's clock at the moment of the scan,
-- not the server's — so the row says so:
--
--   scanned_offline  1 for a row sent from the app's offline queue
--   synced_at        when the server received it; NULL for every
--                    scan recorded live
--
-- The Attendance Records table shows such a row with an "Offline"
-- tag beside the time.
--
-- includes/offline_scan.php adds both columns on first use if this
-- has not been run, so the order of deploy and migration does not
-- matter. This file is the record of it. Keep the two in step.
--
-- Safe to re-run: IF NOT EXISTS (MariaDB).
--
-- Run:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-09-30_add_offline_scans.sql
-- ============================================================

ALTER TABLE attendance_tbl
    ADD COLUMN IF NOT EXISTS scanned_offline TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE attendance_tbl
    ADD COLUMN IF NOT EXISTS synced_at DATETIME NULL DEFAULT NULL;
