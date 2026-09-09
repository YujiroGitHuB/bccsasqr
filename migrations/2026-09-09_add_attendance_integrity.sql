-- ============================================================
-- Sino ang may hawak ng telepono?
--
-- Limang tseke ang mayroon ang crud/submit_attendance.php bago
-- ito nagkaroon ng talaang ito: tama ba ang link, buhay pa ba,
-- hindi pa ba expired, enrolled ba ang estudyante, at hindi pa ba
-- siya sumusumite ngayong araw. Wala ni isa sa mga iyon ang
-- nagtatanong kung SINO ang nasa harap ng screen.
--
-- Kaya ang buong klase ay kayang isumite ng isang tao mula sa
-- isang telepono: i-type ang numero ng kaklase, lalabas pa nga ang
-- pangalan at mukha nito bilang katiyakan na tama ang na-type, at
-- submit. Sampung segundo kada tao.
--
-- Tatlong talaan ang isinusulat nito, at dalawang column sa
-- attendance_links_tbl:
--
--   attendance_audit_tbl       ang ebidensya — anong device, anong
--                              IP, anong oras, at ano ang naging
--                              kahihinatnan ng bawat pagsusumite
--   attendance_ratelimit_tbl   ang bilangan ng mga paghahanap, para
--                              hindi maging listahan ng target ang
--                              crud/verify_student.php
--   room_code_secret           ang binhi ng umiikot na code na
--                              ipinapakita sa harapan ng klase
--
-- Ligtas i-rerun: IF NOT EXISTS ang lahat.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-09-09_add_attendance_integrity.sql
-- ============================================================


-- ── 1. Ang ebidensya ────────────────────────────────────────
--
-- Isang hilera kada pagsusumiteng may kahihinatnan — hindi lamang
-- ang mga pumasa. Ang tinanggihan ang mas mahalaga: ito ang
-- nagsasabing may sumubok, kailan, at mula saan.
--
-- Bakit hiwalay sa attendance_tbl: ang attendance_tbl ay tinitingnan
-- ng mga ulat at ini-export bilang PDF — hindi dapat may IP address
-- at user agent ang isang class record. At ang mga tinanggihang
-- pagsubok ay walang attendance row na pagkakabitan.
--
-- VARCHAR(255) ang user_agent at hindi TEXT: sampung megabyte lamang
-- ang database, at ang unang 255 ay sapat na para makilala ang
-- browser at telepono. May pantanggal ng lumang hilera ang
-- includes/attendance_integrity.php — tatlumpung araw ang itinatago,
-- sapat para may matingnan sa isang buwan ng klase.
CREATE TABLE IF NOT EXISTS attendance_audit_tbl (
    id            INT(11)      NOT NULL AUTO_INCREMENT,
    created_at    DATETIME     NOT NULL DEFAULT current_timestamp(),
    student_no    VARCHAR(20)  NOT NULL,
    short_code    VARCHAR(10)  NOT NULL,
    subject_name  VARCHAR(100) DEFAULT NULL,
    section       VARCHAR(100) DEFAULT NULL,
    instructor_id INT(11)      DEFAULT NULL,

    -- Ang cookie na nakatanim sa browser (tingnan ang
    -- integrity_device_id). Ito ang pangunahing sagot sa "iisang
    -- telepono ba ito?".
    device_id     CHAR(32)     DEFAULT NULL,

    -- Hash ng user agent + wika + laki ng screen + time zone.
    -- Pangalawang senyas lamang: hindi ito humaharang, dahil
    -- magkaparehong-pareho ang dalawang bagong telepono ng
    -- magkaparehong modelo. Nagagamit ito kapag binura ang cookie.
    fingerprint   CHAR(16)     DEFAULT NULL,

    ip            VARCHAR(45)  DEFAULT NULL,   -- 45 = haba ng IPv6
    user_agent    VARCHAR(255) DEFAULT NULL,

    -- Path ng selfie kapag hiniling ito ng spot check. NULL ang
    -- karamihan — hindi lahat ay tinatanong.
    selfie_path   VARCHAR(255) DEFAULT NULL,

    -- ok | device_reuse | bad_room_code | duplicate | not_enrolled
    result        VARCHAR(24)  NOT NULL,

    PRIMARY KEY (id),

    -- Ang tanong na itinatanong kada pagsusumite: "may naisumite na
    -- ba ang device na ito para sa link na ito ngayong araw?"
    KEY idx_device_link (device_id, short_code, created_at),

    -- Para sa pahina ng pagsusuri: mga hinarang, pinakabago muna.
    KEY idx_result_date (result, created_at),

    -- Para sa pantanggal ng lumang hilera.
    KEY idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ── 2. Bilangan ng paghahanap ───────────────────────────────
--
-- Ang crud/verify_student.php ay nagsasauli ng pangalan, course,
-- section at larawan para sa kahit anong numerong ibigay mo. Walang
-- hinihinging link at walang bilangan, kaya kayang i-loop ang
-- 025-001 hanggang 025-2000 at makuha ang buong talaan ng paaralan
-- — kasama ang mismong impormasyong kailangan para magsumite para
-- sa iba.
--
-- Isang hilera kada bucket, hindi kada request: ang bucket ay
-- "verify:ip:203.0.113.9", at inuulit lamang ang bilang sa loob ng
-- kasalukuyang window. Kaya ilang dosenang hilera lamang ito kahit
-- kailan, at tinatanggal ang mga lumipas na.
CREATE TABLE IF NOT EXISTS attendance_ratelimit_tbl (
    bucket       VARCHAR(64) NOT NULL,
    window_start DATETIME    NOT NULL,
    hits         INT(11)     NOT NULL DEFAULT 0,
    PRIMARY KEY (bucket),
    KEY idx_window (window_start)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ── 3. Ang umiikot na code ng silid ─────────────────────────
--
-- Anim na digit na nagpapalit kada tatlumpung segundo, galing sa
-- HMAC ng binhing ito at ng kasalukuyang oras — hindi itinatago sa
-- database ang code mismo, ang binhi lamang. Ipinapakita ito sa
-- projector o pisara; ang wala sa loob ng silid ay walang mababasa.
--
-- NULL ang binhi hangga't hindi binubuksan ang tampok para sa
-- link na iyon, at OFF ang require_room_code sa lahat ng umiiral
-- na link — walang mababago sa mga klaseng tumatakbo na ngayon.
ALTER TABLE attendance_links_tbl
    ADD COLUMN IF NOT EXISTS room_code_secret  CHAR(64)     NULL DEFAULT NULL AFTER expires_at,
    ADD COLUMN IF NOT EXISTS require_room_code TINYINT(1)   NOT NULL DEFAULT 0 AFTER room_code_secret;


-- ── 4. Mga bagong setting ───────────────────────────────────
--
-- device_binding    ON — isang device, isang estudyante kada link
--                   kada araw
-- selfie_spot_rate  15 — bahagdan ng mga pagsusumiteng hihingan ng
--                   selfie. 0 ang nagpapatay nito.
--
-- INSERT IGNORE: hindi binabago ang halagang pinili na ng admin
-- kapag inulit ang migration.
INSERT IGNORE INTO attendance_settings (setting_key, setting_value, updated_at) VALUES
    ('device_binding',   '1',  NOW()),
    ('selfie_spot_rate', '15', NOW());


-- ── Tseke ───────────────────────────────────────────────────
SELECT setting_key, setting_value FROM attendance_settings
WHERE setting_key IN ('device_binding', 'selfie_spot_rate', 'require_student_photo', 'form_locked');

SELECT short_code, is_active, expires_at, require_room_code,
       (room_code_secret IS NOT NULL) AS has_secret
FROM attendance_links_tbl
ORDER BY id DESC
LIMIT 10;
