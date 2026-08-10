-- ============================================================
-- Avatar (profile picture) para sa mga user account
--
-- Bakit: walang hawak na larawan ang users table, kaya static na
-- icon mula sa CDN ang ipinapakita ng topbar para sa LAHAT ng
-- account. Sa isang system na may admin at maraming instructor,
-- walang biswal na palatandaan kung sinong account ang naka-login —
-- lalo na sa mga shared na kompyuter sa faculty room.
--
-- Ang itinatago rito ay PATH lang (hal. "uploads/avatars/user_1.jpg"),
-- hindi ang mismong larawan — pareho sa student_photos.photo_path,
-- para hindi lumobo ang laki ng backup dump.
--
-- NULL ang default: mananatiling initials-based na avatar ang
-- ipinapakita hangga't walang na-upload — walang mababasag na page
-- kahit isang account pa lang ang may larawan.
--
-- Ligtas i-rerun: may IF NOT EXISTS ang ALTER (MariaDB 10.0+).
-- Kung MySQL 8 ang server, tanggalin ang "IF NOT EXISTS" at huwag
-- ulitin ang pagpapatakbo.
--
-- Patakbuhin:
--   mysql -u root bcc_qr_attendance_db < migrations/2026-08-10_add_user_avatar.sql
-- ============================================================

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS avatar VARCHAR(255) DEFAULT NULL
    COMMENT 'Relative path ng profile picture, hal. uploads/avatars/user_1.jpg'
    AFTER email;

-- ── Tseke: dapat lumabas ang column na `avatar` ──────────────
SHOW COLUMNS FROM users LIKE 'avatar';
