<?php
// ============================================================
// Mga kasangkapan para sa attendance links, sa isang lugar.
//
// Tatlong file ang humahawak ng parehong dalawang bagay — ang
// paggawa ng short_code at ang pagtatakda ng expiry: ang listahan
// (pages/get_links_ajax.php), ang pagpapalit ng oras
// (crud/set_link_expiry.php) at ang pagpapalit ng code
// (crud/new_link_code.php). Isang kopya lang nila ang narito, kaya
// hindi maaaring maghiwalay ang tatlo — halimbawa, ang isa ay
// gumagamit ng orasan ng PHP habang ang iba ay sa database.
//
// Since the phone app got its own Links tab (api/v1/handlers/links.php)
// the whole page lives here, not just the two helpers: the list, who
// may change a link, and the three changes. The web endpoints and the
// API call the same functions, so the phone and the browser cannot
// disagree about which links exist or when one closes.
// ============================================================

require_once __DIR__ . '/late.php';

/**
 * Anim na karakter mula sa isang alpabetong walang malabo:
 * hindi kasama ang 0/O at 1/I dahil binabasa at tinitipa ito ng
 * mga estudyante mula sa isang QR na naka-proyekta sa dingding.
 */
function link_generate_code(mysqli $conn, int $length = 6): string
{
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    do {
        $code = '';
        for ($i = 0; $i < $length; $i++) {
            $code .= $chars[random_int(0, strlen($chars) - 1)];
        }

        $chk = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ?");
        $chk->bind_param("s", $code);
        $chk->execute();
        $taken = $chk->get_result()->num_rows > 0;
        $chk->close();
    } while ($taken);

    return $code;
}

/**
 * Binubuo ang SET clause para sa expires_at mula sa POST.
 *
 * Lahat ng oras ay kinakalkula SA LOOB ng SQL. Ang PHP ng app na ito
 * ay nasa Asia/Manila samantalang ang NOW() ng MySQL ay sumusunod sa
 * koneksyon (naka-pin sa +08:00 sa includes/db_connect.php) — pero
 * hangga't ang parehong orasan ang nagtatakda at nagsusuri ng
 * expires_at, hindi mahalaga kung alin ito. Ang pinagbabawal ay ang
 * paghahalo ng dalawa.
 *
 * @return array{sql:?string,types:string,params:array,error:?string}
 *   sql === null   → walang hiniling na pagbabago sa expiry
 *   error !== null → mali ang hiniling; huwag ituloy
 */
function link_expiry_clause(array $in, mysqli $conn): array
{
    $none = ['sql' => null, 'types' => '', 'params' => [], 'error' => null];

    if (!empty($in['clear'])) {
        return ['sql' => 'expires_at = NULL', 'types' => '', 'params' => [], 'error' => null];
    }

    if (($in['preset'] ?? '') === 'eod') {
        // Hanggang katapusan ng araw NGAYON — hindi "+24 na oras".
        return [
            'sql'    => "expires_at = TIMESTAMP(CURDATE(), '23:59:59')",
            'types'  => '',
            'params' => [],
            'error'  => null,
        ];
    }

    if (isset($in['minutes'])) {
        $minutes = (int) $in['minutes'];

        // 1 minuto hanggang 7 araw. Ang link na tatagal nang mahigit
        // isang linggo ay walang pinagkaiba sa walang expiry.
        if ($minutes < 1 || $minutes > 10080) {
            return array_merge($none, ['error' => 'Duration must be between 1 minute and 7 days.']);
        }

        return [
            'sql'    => 'expires_at = DATE_ADD(NOW(), INTERVAL ? MINUTE)',
            'types'  => 'i',
            'params' => [$minutes],
            'error'  => null,
        ];
    }

    if (isset($in['at']) && trim($in['at']) !== '') {
        // Galing sa <input type="datetime-local">: "2026-08-16T10:00".
        $raw = trim($in['at']);
        $dt  = DateTime::createFromFormat('Y-m-d\TH:i', $raw)
            ?: DateTime::createFromFormat('Y-m-d\TH:i:s', $raw);

        if (!$dt) {
            return array_merge($none, ['error' => 'Invalid date and time.']);
        }

        $at = $dt->format('Y-m-d H:i:s');

        // Ang hinaharap lang ang may saysay, at ang database pa rin
        // ang nagsasabi kung ano ang "ngayon". Hiwalay na tanong ito
        // at hindi isinama sa WHERE ng UPDATE: kapag pareho ang bagong
        // petsa sa luma, zero ang affected_rows ng MySQL, at hindi na
        // mapagkakaiba ang "walang binago" sa "lumipas na".
        $chk = $conn->prepare("SELECT (? > NOW()) AS ok");
        $chk->bind_param("s", $at);
        $chk->execute();
        $ok = (int) $chk->get_result()->fetch_assoc()['ok'] === 1;
        $chk->close();

        if (!$ok) {
            return array_merge($none, ['error' => 'That time has already passed.']);
        }

        return ['sql' => 'expires_at = ?', 'types' => 's', 'params' => [$at], 'error' => null];
    }

    return $none;
}

/**
 * Ang kalagayan ng isang link pagkatapos baguhin, galing mismo sa
 * database — hindi ang hinuha ng PHP kung ano ang naging resulta ng
 * pindot. Ito ang eksaktong halagang susuriin ng
 * pages/daily_attendance.php at crud/submit_attendance.php mamaya.
 */
function link_state(mysqli $conn, string $short_code): array
{
    $stmt = $conn->prepare("
        SELECT short_code,
               expires_at,
               (expires_at IS NOT NULL AND expires_at <= NOW())  AS is_expired,
               TIMESTAMPDIFF(SECOND, NOW(), expires_at)          AS expires_in,
               DATE_FORMAT(expires_at, '%b %e, %Y %l:%i %p')     AS expires_label,
               -- Just the time when it is today: on a card, the full
               -- date is mostly noise and wraps mid-phrase.
               IF(DATE(expires_at) = CURDATE(),
                  DATE_FORMAT(expires_at, '%l:%i %p'),
                  DATE_FORMAT(expires_at, '%b %e, %l:%i %p'))   AS expires_short
        FROM attendance_links_tbl
        WHERE short_code = ?
    ");
    $stmt->bind_param("s", $short_code);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc() ?: [];

    // The card is repainted from this answer alone, so it carries the
    // late cutoff too — otherwise changing the expiry would wipe the
    // late pill off the card until the next reload.
    $late = late_states($conn, [$short_code])[$short_code];

    return array_merge([
        'short_code'    => $short_code,
        'expires_at'    => $row['expires_at']    ?? null,
        'expires_label' => $row['expires_label'] ?? null,
        'expires_short' => isset($row['expires_short']) ? trim($row['expires_short']) : null,
        'expires_in'    => isset($row['expires_in']) && $row['expires_in'] !== null ? (int) $row['expires_in'] : null,
        'is_expired'    => isset($row['is_expired']) && (int) $row['is_expired'] === 1,
    ], $late);
}

/**
 * May this account change this link? An admin may change any link, an
 * instructor only their own.
 */
function link_owned(mysqli $conn, string $short_code, int $user_id, bool $is_admin): bool
{
    if ($is_admin) {
        $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ?");
        $own->bind_param("s", $short_code);
    } else {
        $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ? AND instructor_id = ?");
        $own->bind_param("si", $short_code, $user_id);
    }
    $own->execute();
    $owned = $own->get_result()->num_rows > 0;
    $own->close();

    return $owned;
}

/**
 * Itakda, palawigin o alisin ang expiry — nang HINDI nagbabago ang
 * short_code. Ang "Extend": kaparehong klase, kaparehong URL.
 *
 * $in holds what link_expiry_clause() reads: minutes, preset=eod,
 * at, or clear.
 *
 * @return array{error:?string,state:?array}
 */
function link_set_expiry(mysqli $conn, string $short_code, array $in): array
{
    $clause = link_expiry_clause($in, $conn);

    if ($clause['error'] !== null) {
        return ['error' => $clause['error'], 'state' => null];
    }

    if ($clause['sql'] === null) {
        return ['error' => 'Nothing to set.', 'state' => null];
    }

    $stmt   = $conn->prepare("UPDATE attendance_links_tbl SET {$clause['sql']} WHERE short_code = ?");
    $types  = $clause['types'] . 's';
    $params = array_merge($clause['params'], [$short_code]);
    $stmt->bind_param($types, ...$params);

    if (!$stmt->execute()) {
        return ['error' => 'Database error', 'state' => null];
    }

    return ['error' => null, 'state' => link_state($conn, $short_code)];
}

/**
 * Set or remove the late cutoff. The link stays open either way.
 *
 * $in holds what late_clause() reads: minutes, at (HH:MM, today), or
 * clear.
 *
 * @return array{error:?string,state:?array}
 */
function link_set_late(mysqli $conn, string $short_code, array $in): array
{
    if (!late_ready($conn)) {
        return ['error' => 'Late marking is not available yet — the database could not be updated.', 'state' => null];
    }

    $clause = late_clause($in);

    if ($clause['error'] !== null) {
        return ['error' => $clause['error'], 'state' => null];
    }

    if ($clause['sql'] === null) {
        return ['error' => 'Nothing to set.', 'state' => null];
    }

    $stmt   = $conn->prepare("UPDATE attendance_links_tbl SET {$clause['sql']} WHERE short_code = ?");
    $types  = $clause['types'] . 's';
    $params = array_merge($clause['params'], [$short_code]);
    $stmt->bind_param($types, ...$params);

    if (!$stmt->execute()) {
        return ['error' => 'Database error', 'state' => null];
    }

    return ['error' => null, 'state' => link_state($conn, $short_code)];
}

/**
 * Bagong short_code para sa parehong klase — ang "bagong session".
 * Tingnan ang crud/new_link_code.php kung bakit UPDATE at hindi INSERT.
 *
 * $in may carry an expiry for the new link (as link_set_expiry()); with
 * none, the new link has no expiry until one is set. The late cutoff
 * never carries over: it belonged to the old class.
 *
 * @return array{error:?string,state:?array}  state includes old_code
 */
function link_renew(mysqli $conn, string $old_code, array $in): array
{
    // Walang hiniling na oras → NULL. Hindi minana ang luma: lumipas na
    // iyon, kaya ipapanganak na patay ang bagong code.
    $clause = link_expiry_clause($in, $conn);

    if ($clause['error'] !== null) {
        return ['error' => $clause['error'], 'state' => null];
    }

    $set    = $clause['sql'] ?? 'expires_at = NULL';
    $types  = $clause['types'];
    $params = $clause['params'];

    if (late_ready($conn)) {
        $set .= ', late_after = NULL';
    }

    // Kasama ang is_active = 1: maaaring pinatay ang link (manu-mano o
    // dahil nawalan ng enrolled na estudyante), at ang paghingi ng
    // bagong code ay malinaw na kahilingang buksang muli ito.
    $new_code = link_generate_code($conn);

    $stmt = $conn->prepare("
        UPDATE attendance_links_tbl
        SET short_code = ?, is_active = 1, $set
        WHERE short_code = ?
    ");
    $stmt->bind_param('s' . $types . 's', ...array_merge([$new_code], $params, [$old_code]));

    if (!$stmt->execute()) {
        return ['error' => 'Database error', 'state' => null];
    }

    return [
        'error' => null,
        'state' => array_merge(['old_code' => $old_code], link_state($conn, $new_code)),
    ];
}

/**
 * Idinidikit ang kalagayan ng expiry at ng late cutoff sa bawat link.
 *
 * Ang bawat halaga ay galing sa database — kasama ang "ngayon". Ang
 * pages/get_links_ajax.php, ang daily_attendance.php at ang
 * deactivate_link.php ay walang date_default_timezone_set samantalang
 * meron ang submit_attendance.php; kung PHP ang magkukwenta ng
 * natitirang oras, ilang oras ang pagkakaiba ng sinasabi ng card sa
 * aktuwal na tinatanggap ng server. Isang orasan lang: NOW().
 *
 * Kept apart from links_for_user() because the web page caches the
 * list in the session and must still refresh this on every answer: a
 * cached countdown would be wrong.
 */
function links_attach_state(mysqli $conn, array $links): array
{
    if (empty($links)) return $links;

    $codes = array_column($links, 'short_code');
    $marks = implode(',', array_fill(0, count($codes), '?'));

    $stmt = $conn->prepare("
        SELECT short_code,
               expires_at,
               (expires_at IS NOT NULL AND expires_at <= NOW())  AS is_expired,
               TIMESTAMPDIFF(SECOND, NOW(), expires_at)          AS expires_in,
               DATE_FORMAT(expires_at, '%b %e, %Y %l:%i %p')     AS expires_label,
               -- Just the time when it is today: on a card, the full
               -- date is mostly noise and wraps mid-phrase.
               IF(DATE(expires_at) = CURDATE(),
                  DATE_FORMAT(expires_at, '%l:%i %p'),
                  DATE_FORMAT(expires_at, '%b %e, %l:%i %p'))   AS expires_short
        FROM attendance_links_tbl
        WHERE short_code IN ($marks)
    ");
    $stmt->bind_param(str_repeat('s', count($codes)), ...$codes);
    $stmt->execute();

    $byCode = [];
    $res    = $stmt->get_result();
    while ($row = $res->fetch_assoc()) {
        $byCode[$row['short_code']] = $row;
    }

    // The late cutoff rides along for the same reason the expiry does:
    // it is a countdown, and a cached one would be wrong.
    $late = late_states($conn, $codes);

    foreach ($links as &$l) {
        $e = $byCode[$l['short_code']] ?? null;

        $l['expires_at']    = $e['expires_at']    ?? null;
        $l['expires_label'] = $e['expires_label'] ?? null;
        $l['expires_short'] = isset($e['expires_short']) ? trim($e['expires_short']) : null;
        $l['expires_in']    = ($e && $e['expires_in'] !== null) ? (int) $e['expires_in'] : null;
        $l['is_expired']    = $e ? ((int) $e['is_expired'] === 1) : false;

        $l = array_merge($l, $late[$l['short_code']]);
    }
    unset($l);

    return $links;
}

/**
 * The Attendance Links page's list for one account, as
 * [['subject' => row, 'short_code' => code], …] plus the links that
 * were given a new code on the way ('rotated': [['old', 'new'], …]).
 *
 * Opening the list is what keeps the table in order — there is no
 * cron on this host: a link is created for every (subject, section)
 * the account teaches that has students enrolled; one whose class lost
 * its last student is deactivated; one that expired on an earlier day
 * gets a fresh code. The web page and the phone app both call this,
 * so either one opening does the upkeep for both.
 *
 * $role is users.role: an admin sees every instructor's links, an
 * instructor their own, anyone else none.
 */
function links_for_user(mysqli $conn, int $user_id, string $role): array
{
    // ─── 1. Fetch subjects ────────────────────────────────────────────────
    // JOIN now uses ss.section = ist.section (from student_subjects_tbl)
    // instead of st.section = ist.section (from students_tbl).
    // This correctly handles irreg students and ensures links appear/disappear
    // based on actual enrollment records — not the student's original section.
    $subjects = [];

    if ($role === 'admin') {
        $query = "
            SELECT DISTINCT
                s.id            AS subject_id,
                s.subject_code,
                s.subject_name,
                CONCAT(ist.course, '-', ist.section) AS section,
                u.id            AS instructor_id,
                u.name          AS instructor_name,
                CASE WHEN si.instructor_id = ? THEN 1 ELSE 0 END AS is_mine
            FROM subject_instructors_tbl si
            INNER JOIN subjects_tbl s
                ON si.subject_id = s.id
            INNER JOIN users u
                ON si.instructor_id = u.id
            INNER JOIN instructor_section_tbl ist
                ON ist.instructor_id = si.instructor_id
            INNER JOIN student_subjects_tbl ss
                ON ss.subject_code = s.subject_code
               AND ss.section = ist.section
            INNER JOIN students_tbl st
                ON st.student_no = ss.student_no
            ORDER BY is_mine DESC, ist.course, ist.section, s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $subjects[] = $row;
        }

    } elseif ($role === 'instructor') {
        $query = "
            SELECT DISTINCT
                s.id            AS subject_id,
                s.subject_code,
                s.subject_name,
                CONCAT(ist.course, '-', ist.section) AS section,
                u.id            AS instructor_id,
                u.name          AS instructor_name
            FROM subject_instructors_tbl si
            INNER JOIN subjects_tbl s
                ON si.subject_id = s.id
            INNER JOIN users u
                ON si.instructor_id = u.id
            INNER JOIN instructor_section_tbl ist
                ON ist.instructor_id = si.instructor_id
            INNER JOIN student_subjects_tbl ss
                ON ss.subject_code = s.subject_code
               AND ss.section = ist.section
            INNER JOIN students_tbl st
                ON st.student_no = ss.student_no
            WHERE si.instructor_id = ?
            ORDER BY ist.course, ist.section, s.subject_name
        ";
        $stmt = $conn->prepare($query);
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $subjects[] = $row;
        }
    }

    // ─── 2. Build valid keys from current subjects ────────────────────────
    $valid_keys = [];
    foreach ($subjects as $s) {
        $valid_keys[] = $s['subject_id'] . '|' . $s['section'] . '|' . $s['instructor_id'];
    }

    // ─── 2b. Fetch ALL active links for this instructor/admin ─────────────
    // Must fetch ALL — not just ones matching current subjects —
    // so we can deactivate orphaned links (enrollment deleted).
    $all_active_links = [];

    // is_stale: nag-expire sa NAUNANG araw. Tingnan ang 2c.
    $stale_sql = "(expires_at IS NOT NULL AND DATE(expires_at) < CURDATE()) AS is_stale";

    if ($role === 'admin') {
        $all_stmt = $conn->prepare("
            SELECT subject_id, section, instructor_id, short_code, $stale_sql
            FROM attendance_links_tbl
            WHERE is_active = 1
        ");
        $all_stmt->execute();
    } else {
        $all_stmt = $conn->prepare("
            SELECT subject_id, section, instructor_id, short_code, $stale_sql
            FROM attendance_links_tbl
            WHERE is_active = 1 AND instructor_id = ?
        ");
        $all_stmt->bind_param("i", $user_id);
        $all_stmt->execute();
    }

    $all_result = $all_stmt->get_result();
    while ($row = $all_result->fetch_assoc()) {
        $key = $row['subject_id'] . '|' . $row['section'] . '|' . $row['instructor_id'];
        $all_active_links[$key] = [
            'short_code' => $row['short_code'],
            'is_stale'   => (int) $row['is_stale'] === 1,
        ];
    }

    // ─── 2c. Auto-deactivate links with no more enrolled students ─────────
    //         + bagong code para sa mga nag-expire noong nakaraang araw
    //
    // Walang cron sa hosting na ito, kaya walang tumatakbo sa mismong
    // sandali ng pag-expire — isang WHERE clause lang ang expiry,
    // sinusuri kapag may nagtanong. Ang pinakamalapit na posibleng
    // "awtomatiko" ay ito: sa susunod na pagbukas ng pahina.
    //
    // Bakit sa naunang araw at hindi kaagad pagkatapos mag-expire: ang
    // link na nagsara kaninang alas-otso ay maaaring kailanganin pang
    // palawigin ngayong hapon (natagalan ang klase, may hindi
    // nakapag-scan) — at ang pagpapalawig ay may saysay lamang kung
    // kaparehong URL pa rin ang hawak ng mga estudyante. Ibang araw,
    // ibang klase: doon na dapat mamatay ang lumang URL.
    //
    // Walang expiry ang bagong code hangga't hindi ka nagtatakda —
    // hindi minana ang luma, dahil hindi alam ng sistema kung kailan
    // ang susunod mong klase.
    $existing_links = [];
    $rotated        = [];

    foreach ($all_active_links as $key => $info) {
        $short_code = $info['short_code'];

        if (!in_array($key, $valid_keys)) {
            // No enrolled students anymore — deactivate
            $deactivate = $conn->prepare("
                UPDATE attendance_links_tbl SET is_active = 0 WHERE short_code = ?
            ");
            $deactivate->bind_param("s", $short_code);
            $deactivate->execute();
            continue;
        }

        if ($info['is_stale']) {
            $new_code = link_generate_code($conn);
            // The late cutoff goes with the expiry: both belonged to the
            // meeting that is over.
            $lateReset = late_ready($conn) ? ', late_after = NULL' : '';
            $rot = $conn->prepare("
                UPDATE attendance_links_tbl
                SET short_code = ?, expires_at = NULL $lateReset
                WHERE short_code = ?
            ");
            $rot->bind_param("ss", $new_code, $short_code);

            if ($rot->execute()) {
                $rotated[]  = ['old' => $short_code, 'new' => $new_code];
                $short_code = $new_code;
            }
        }

        // Still valid — keep in map for Step 3
        $existing_links[$key] = $short_code;
    }

    // ─── 3. Build links ───────────────────────────────────────────────────
    $links = [];

    foreach ($subjects as $subject) {
        $key = $subject['subject_id'] . '|' . $subject['section'] . '|' . $subject['instructor_id'];

        if (isset($existing_links[$key])) {
            $short_code = $existing_links[$key];
        } else {
            // Ang pagsusuri kung libre pa ang code ay nasa loob na ng
            // link_generate_code().
            $short_code = link_generate_code($conn);

            $reuse = $conn->prepare("
                SELECT short_code FROM attendance_links_tbl
                WHERE subject_id = ? AND section = ? AND instructor_id = ? AND is_active = 0
                ORDER BY id DESC LIMIT 1
            ");
            $reuse->bind_param("isi", $subject['subject_id'], $subject['section'], $subject['instructor_id']);
            $reuse->execute();
            $reuse_result = $reuse->get_result();

            if ($reuse_result->num_rows > 0) {
                $old = $reuse_result->fetch_assoc();
                $upd = $conn->prepare("UPDATE attendance_links_tbl SET short_code = ?, is_active = 1 WHERE short_code = ?");
                $upd->bind_param("ss", $short_code, $old['short_code']);
                $upd->execute();
            } else {
                $ins = $conn->prepare("
                    INSERT INTO attendance_links_tbl
                        (short_code, subject_id, subject_code, subject_name, section, instructor_id, instructor_name, created_by)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ");
                $ins->bind_param("sisssssi",
                    $short_code,
                    $subject['subject_id'],
                    $subject['subject_code'],
                    $subject['subject_name'],
                    $subject['section'],
                    $subject['instructor_id'],
                    $subject['instructor_name'],
                    $user_id
                );
                $ins->execute();
            }
        }

        $links[] = [
            'subject'    => $subject,
            'short_code' => $short_code,
        ];
    }

    return ['links' => $links, 'rotated' => $rotated];
}
