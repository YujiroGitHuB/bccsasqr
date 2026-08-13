-- ============================================================
--  Per-instructor access control.
--
--  Until now the only thing that decided what somebody could do was
--  `users.role` — admin got everything, instructor got a fixed set
--  baked into the code. An admin could not, say, let one instructor
--  record attendance but not delete it.
--
--  A row here = that permission is GRANTED. No row = not granted.
--  Admins are not stored: isAdmin() short-circuits can() and always
--  passes, so there is no way to lock an admin out of their own
--  system by unticking boxes.
--
--  The catalog of valid keys lives in includes/permissions.php
--  (PERMISSION_CATALOG) — that file is the source of truth for
--  labels and grouping; this table only stores what was granted.
-- ============================================================

CREATE TABLE IF NOT EXISTS `user_permissions_tbl` (
  `user_id`    int(11)     NOT NULL,
  `permission` varchar(64) NOT NULL COMMENT 'Key mula sa PERMISSION_CATALOG, hal. attendance.record',
  `granted_at` timestamp   NOT NULL DEFAULT current_timestamp(),
  `granted_by` int(11)     DEFAULT NULL COMMENT 'users.id ng admin na nag-grant',
  PRIMARY KEY (`user_id`, `permission`),
  KEY `idx_user_permissions_user` (`user_id`),
  CONSTRAINT `fk_user_permissions_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ── Seed ────────────────────────────────────────────────────
-- Every instructor that already exists keeps exactly what they
-- could do before this migration ran, so nobody loses access the
-- moment it is applied. Narrowing it down is then the admin's
-- choice, one instructor at a time, from Manage Users → Access.
--
-- INSERT IGNORE so re-running the migration is harmless.
INSERT IGNORE INTO `user_permissions_tbl` (`user_id`, `permission`)
SELECT u.`id`, p.`permission`
FROM `users` u
CROSS JOIN (
              SELECT 'attendance.view'   AS `permission`
    UNION ALL SELECT 'attendance.record'
    UNION ALL SELECT 'attendance.import'
    UNION ALL SELECT 'attendance.delete'
    UNION ALL SELECT 'attendance.export'
    UNION ALL SELECT 'links.manage'
    UNION ALL SELECT 'students.photos'
    UNION ALL SELECT 'enrollment.manage'
    UNION ALL SELECT 'qr.generator'
    UNION ALL SELECT 'qr.scanner'
    UNION ALL SELECT 'qr.tracker'
) p
WHERE u.`role` = 'instructor';
