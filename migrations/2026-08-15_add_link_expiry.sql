-- ============================================================
-- Expiration ng attendance links.
--
-- Bakit: walang katapusan ang buhay ng isang link. Nananatiling
-- bukas ang `is_active = 1` hanggang may manu-manong pumindot ng
-- deactivate, kaya ang link na ipinadala para sa klase kaninang
-- 8AM ay tumatanggap pa rin ng scan ng hatinggabi — mula kahit
-- saan, ng kahit sinong may kopya ng URL.
--
-- NULL = walang expiry, kaya walang mababago sa mga umiiral na
-- link pagkatapos i-apply ito. Ang bawat link ay walang expiry
-- hangga't hindi ka nagtatakda mula sa Attendance Links page.
--
-- Bakit DATETIME at hindi TIMESTAMP: ang TIMESTAMP ay may saklaw
-- lamang hanggang 2038 at kusang kino-convert ang time zone kada
-- basa. Isang orasan lang ang dapat masunod dito — ang orasan ng
-- database (NOW()) — dahil tatlo sa apat na file na humahawak ng
-- links ay walang date_default_timezone_set, kaya ilang oras ang
-- pagkakaiba kung PHP ang magkukwenta.
--
-- Walang index: apatnapung hilera ang talaang ito at laging
-- hinahanap sa pamamagitan ng short_code (unique na). Ang index sa
-- expires_at ay puro bayad sa 10MB na limitasyon, walang bilis na
-- naibabalik.
--
-- Ligtas i-rerun: IF NOT EXISTS ang ADD COLUMN.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-15_add_link_expiry.sql
-- ============================================================

ALTER TABLE attendance_links_tbl
    ADD COLUMN IF NOT EXISTS expires_at DATETIME NULL DEFAULT NULL AFTER is_active;

-- ── Tseke: dapat nandiyan na ang column, at NULL ang lahat ───
SELECT short_code,
       is_active,
       expires_at,
       (expires_at IS NOT NULL AND expires_at <= NOW()) AS is_expired
FROM attendance_links_tbl
ORDER BY id DESC
LIMIT 10;
