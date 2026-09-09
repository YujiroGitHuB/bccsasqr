<?php
// ============================================================
// Isang salaan, tatlong labasan.
//
// Ang pages/attendance_integrity.php, ang CSV at ang PDF ay dapat
// magpakita ng PAREHONG hilera para sa parehong URL — kung hindi,
// ang ini-export mo ay hindi ang tinitingnan mo.
//
// Ngunit hindi iyon ang tunay na dahilan ng file na ito. Ang
// pinakaunang linya ng salaan ay ito:
//
//     ang instruktor ay ang sarili niyang klase lamang
//
// Tatlong kopya niyon ang mangangahulugang tatlong pagkakataong
// makalimutan ito, at ang pagkakalimot ay hindi mukhang sira: ang
// pahina ay gumagana pa rin, may lalabas pa ring listahan — ang
// mga estudyante lamang ay sa ibang guro. Ang butas na hindi
// nagsasabing butas siya ay ang uring nananatili nang matagal.
//
// Kaya isang kopya, at ang tatlo ay tumatawag nito.
//
// Tumatanggap ng $_GET at hindi bumabasa nito nang diretso: mas
// madaling subukan, at malinaw kung ano ang pinagmumulan.
// ============================================================

/** Ang mga kahihinatnang may pagkukusa — ang laman ng "Flagged". */
const INTEGRITY_FLAGGED = ['device_reuse', 'not_enrolled', 'lookup_limit', 'no_student', 'bad_link'];

/** Ang mga halagang tinatanggap ng ?show= */
const INTEGRITY_SHOWS = ['flagged', 'all', 'ok', 'device_reuse', 'duplicate', 'not_enrolled', 'lookup_limit'];

/**
 * Binabasa ang salaan mula sa query string at itinatayo ang SQL.
 *
 * Ang talahanayan ay dapat naka-alias bilang `a` sa tumatawag —
 * ganoon isinulat ang bawat sugnay dito.
 *
 * @return array {
 *   days, show, class, q, device        ang nabasang halaga
 *   where, types, params                saklaw at salaan, WALANG result
 *   result_where, result_types, result_params
 *   all_where, all_types, all_params    ang dalawa, pinagsama
 * }
 */
function integrity_filters(array $get, bool $is_admin, int $user_id): array
{
    // Ang audit ay itinatago nang tatlumpung araw
    // (INTEGRITY_AUDIT_DAYS), kaya walang saysay ang mas malayo pa.
    $days = (int) ($get['days'] ?? 7);
    if (!in_array($days, [1, 7, 30], true)) $days = 7;

    $show = $get['show'] ?? 'flagged';
    if (!in_array($show, INTEGRITY_SHOWS, true)) $show = 'flagged';

    $class = substr(trim((string) ($get['class'] ?? '')), 0, 10);
    $q     = substr(trim((string) ($get['q'] ?? '')), 0, 60);

    // 32 hex ang buo, pero ang ipinapakita ng talahanayan ay ang
    // unang walo — at iyon ang dala ng link na pinindot.
    $device = (string) ($get['device'] ?? '');
    if (!preg_match('/^[0-9a-f]{1,32}$/', $device)) $device = '';

    $where  = ' a.created_at >= DATE_SUB(NOW(), INTERVAL ? DAY) ';
    $types  = 'i';
    $params = [$days];

    // ── Ang linyang hindi dapat makalimutan ──────────────────
    if (!$is_admin) {
        $where .= ' AND a.instructor_id = ? ';
        $types .= 'i';
        $params[] = $user_id;
    }

    if ($class !== '') {
        $where .= ' AND a.short_code = ? ';
        $types .= 's';
        $params[] = $class;
    }

    if ($device !== '') {
        $where .= ' AND a.device_id LIKE ? ';
        $types .= 's';
        $params[] = $device . '%';
    }

    if ($q !== '') {
        // EXISTS at hindi JOIN: ginagamit din ito ng mga tanong na
        // may COUNT(DISTINCT student_no), at hindi dapat
        // maapektuhan iyon ng hilerang idinagdag ng isang join.
        $where .= ' AND (a.student_no LIKE ?
                         OR EXISTS (SELECT 1 FROM students_tbl sq
                                    WHERE sq.student_no = a.student_no
                                      AND sq.fullname LIKE ?)) ';
        $types .= 'ss';
        $params[] = '%' . $q . '%';
        $params[] = '%' . $q . '%';
    }

    // Hiwalay ang result: ang mga tile sa itaas ng pahina ay
    // nagbibilang sa loob ng saklaw ngunit sa kabila ng
    // kahihinatnan — kung hindi, ang pagpindot sa isa ay gagawing 0
    // ang apat sa tabi nito.
    $resultWhere  = '';
    $resultTypes  = '';
    $resultParams = [];

    if ($show === 'flagged') {
        $resultWhere = " AND a.result IN ('" . implode("', '", INTEGRITY_FLAGGED) . "') ";
    } elseif ($show !== 'all') {
        $resultWhere  = ' AND a.result = ? ';
        $resultTypes  = 's';
        $resultParams = [$show];
    }

    return [
        'days'   => $days,
        'show'   => $show,
        'class'  => $class,
        'q'      => $q,
        'device' => $device,

        'where'  => $where,
        'types'  => $types,
        'params' => $params,

        'result_where'  => $resultWhere,
        'result_types'  => $resultTypes,
        'result_params' => $resultParams,

        'all_where'  => $where . $resultWhere,
        'all_types'  => $types . $resultTypes,
        'all_params' => array_merge($params, $resultParams),
    ];
}

/**
 * Ang label ng kahihinatnan, para sa mga pamagat at file name.
 * Ang kulay at ikon ay nasa pahina — ito ang teksto lamang, at
 * ginagamit ito ng dalawang export.
 */
function integrity_show_label(string $show): string
{
    switch ($show) {
        case 'all':          return 'Everything';
        case 'flagged':      return 'Flagged';
        case 'ok':           return 'Saved';
        case 'device_reuse': return 'Same device';
        case 'duplicate':    return 'Repeats';
        case 'not_enrolled': return 'Not enrolled';
        case 'lookup_limit': return 'Lookup limit';
        default:             return ucfirst($show);
    }
}
