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
// ============================================================

/**
 * Kaya bang galawin ng nakalog-in na user ang link na ito?
 *
 * Ang admin ay nakakagalaw ng kahit ano; ang instructor ay sa kanya
 * lamang. Apat nang endpoint ang nagtatanong nito — ang expiry, ang
 * bagong code, ang room code at ang switch nito — at ang sagot ay
 * dapat pare-pareho sa apat. Isang endpoint na nakalimot ng tseke ay
 * pintuan papasok sa klase ng ibang instruktor.
 */
function link_owned_by(mysqli $conn, string $short_code, int $user_id, string $role): bool
{
    if ($role === 'admin') {
        $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ?");
        $own->bind_param("s", $short_code);
    } else {
        $own = $conn->prepare("SELECT id FROM attendance_links_tbl WHERE short_code = ? AND instructor_id = ?");
        $own->bind_param("si", $short_code, $user_id);
    }

    $own->execute();
    $found = $own->get_result()->num_rows > 0;
    $own->close();

    return $found;
}

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
               DATE_FORMAT(expires_at, '%b %e, %Y %l:%i %p')     AS expires_label
        FROM attendance_links_tbl
        WHERE short_code = ?
    ");
    $stmt->bind_param("s", $short_code);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc() ?: [];

    return [
        'short_code'    => $short_code,
        'expires_at'    => $row['expires_at']    ?? null,
        'expires_label' => $row['expires_label'] ?? null,
        'expires_in'    => isset($row['expires_in']) && $row['expires_in'] !== null ? (int) $row['expires_in'] : null,
        'is_expired'    => isset($row['is_expired']) && (int) $row['is_expired'] === 1,
    ];
}
