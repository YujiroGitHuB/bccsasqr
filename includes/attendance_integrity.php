<?php
// ============================================================
// Kung sino ang may hawak ng telepono, sa isang lugar.
//
// Ang includes/photo_requirement.php ay isinulat dahil naghiwalay
// ang dalawang pintuan ng attendance — ang scanner at ang link —
// at ang tuntuning ipinatupad ng isa ay hindi alam ng isa. Ganoon
// din ang dahilan ng file na ito. Apat na bagay ang hinahawakan:
//
//   1. device_id     — ang cookie na nagsasabing iisang telepono
//   2. rate limit    — ang bilangan ng paghahanap ng numero
//   3. audit         — ang talaan ng bawat pagsusumite
//   4. lihim         — ang HMAC key na pumipirma sa device_id
//
// Dalawang file ang tumatawag nito: crud/verify_student.php at
// crud/submit_attendance.php. Kung maghihiwalay silang muli, ang
// butas ay bubukas sa mas maluwag sa dalawa — gaya ng nangyari sa
// larawan.
//
// Walang tinatanggihan ang file na ito nang mag-isa. Nagsasagot
// lamang ito ng tanong; ang tumatawag ang nagpapasya.
// ============================================================

const INTEGRITY_COOKIE     = 'bcc_did';
const INTEGRITY_AUDIT_DAYS = 30;   // gaano katagal itinatago ang talaan


// ─────────────────────────────────────────────────────────────
// 4. Ang lihim
// ─────────────────────────────────────────────────────────────

/**
 * Ang HMAC key na pumipirma sa device cookie.
 *
 * Nauuna ang INTEGRITY_SECRET sa includes/config.php kapag
 * itinakda — doon dapat ito sa isang tunay na deployment, dahil
 * hindi nakikita ng sinumang nakakabasa ng database ang file na
 * iyon. Kapag wala, gumagawa ito ng isa at itinatago sa
 * attendance_settings, para hindi kailangang mag-edit ng file ang
 * paaralang nag-a-upload lamang ng bagong bersyon sa hosting.
 *
 * Ang pagpapalit nito ay pagpapawalang-bisa ng lahat ng device
 * cookie — walang mawawalang attendance, magsisimula lamang muli
 * ang pagkilala sa bawat telepono.
 */
function integrity_secret(mysqli $conn): string
{
    static $cached = null;
    if ($cached !== null) return $cached;

    if (defined('INTEGRITY_SECRET') && INTEGRITY_SECRET !== '') {
        return $cached = INTEGRITY_SECRET;
    }

    $res = $conn->query("
        SELECT setting_value FROM attendance_settings
        WHERE setting_key = 'integrity_secret' LIMIT 1
    ");

    if ($res && $res->num_rows > 0) {
        $val = $res->fetch_assoc()['setting_value'];
        if ($val !== '') return $cached = $val;
    }

    // Unang pagtakbo. INSERT IGNORE at saka muling basahin: kung
    // dalawang request ang sabay na nakarating dito, isa lamang ang
    // mananalo at pareho silang magbabasa ng parehong halaga —
    // dalawang magkaibang lihim ang mangangahulugang biglaang
    // hindi na makikilala ang bawat device.
    $new  = bin2hex(random_bytes(32));
    $stmt = $conn->prepare("
        INSERT IGNORE INTO attendance_settings (setting_key, setting_value, updated_at)
        VALUES ('integrity_secret', ?, NOW())
    ");
    $stmt->bind_param("s", $new);
    $stmt->execute();
    $stmt->close();

    $res = $conn->query("
        SELECT setting_value FROM attendance_settings
        WHERE setting_key = 'integrity_secret' LIMIT 1
    ");

    return $cached = ($res && $res->num_rows > 0)
        ? $res->fetch_assoc()['setting_value']
        : $new;
}

/**
 * May ganitong column ba ang attendance_audit_tbl?
 *
 * Lumalaki ang talahanayang ito sa pamamagitan ng migration, at ang
 * mga pahinang bumabasa nito ay kailangang gumana kahit hindi pa
 * napapatakbo ang pinakabago — nawawala lamang ang isang hanay,
 * hindi ang buong pahina.
 *
 * SHOW COLUMNS at hindi information_schema.columns: sa isang shared
 * hosting na may libu-libong talahanayan ng ibang account, ang
 * information_schema ay isang tanong na kayang tumagal nang mas
 * matagal kaysa sa lahat ng tunay na tanong ng pahina — magkasama.
 * Ang SHOW COLUMNS ay tumitingin lamang sa isang talahanayan.
 *
 * Static ang cache: minsan kada request, gaano man karaming
 * tumawag.
 */
function integrity_has_column(mysqli $conn, string $column): bool
{
    static $cache = [];
    if (isset($cache[$column])) return $cache[$column];

    try {
        // Walang placeholder ang SHOW COLUMNS. Ang pangalan ay
        // laging nakasulat sa code at hindi galing sa gumagamit,
        // ngunit ini-escape pa rin — ang susunod na tumawag nito ay
        // hindi nakakabasa ng talatang ito.
        $res = $conn->query(
            "SHOW COLUMNS FROM attendance_audit_tbl LIKE '"
            . $conn->real_escape_string($column) . "'"
        );
        return $cache[$column] = ($res && $res->num_rows > 0);
    } catch (Throwable $e) {
        // Wala pa ang buong talahanayan. Wala rin ang column.
        return $cache[$column] = false;
    }
}

/**
 * Ang halaga ng isang setting sa attendance_settings, may kasamang
 * default kapag wala pang hilera. Kapareho ng ginagawa ng
 * photo_is_required(), pangkalahatan lamang.
 */
function integrity_setting(mysqli $conn, string $key, string $default = ''): string
{
    $stmt = $conn->prepare("
        SELECT setting_value FROM attendance_settings
        WHERE setting_key = ? LIMIT 1
    ");
    $stmt->bind_param("s", $key);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return ($row && $row['setting_value'] !== '') ? $row['setting_value'] : $default;
}


// ─────────────────────────────────────────────────────────────
// 1. Ang device
// ─────────────────────────────────────────────────────────────

/**
 * Ang ID ng browser na ito, itinatanim kapag wala pa.
 *
 * Pinipirmahan ang halaga (id.hmac) para hindi kayang mag-imbento
 * ng bagong ID sa pamamagitan ng pag-edit ng cookie sa devtools —
 * kaya pa ring BURAHIN ito, at iyon ang hangganan ng tampok na
 * ito: humaharang ito sa madali, hindi sa determinado. Ang
 * determinado ang dahilan kung bakit may audit trail — ang
 * nakakalusot ay nakikita pa rin sa pages/attendance_integrity.php.
 *
 * httpOnly: walang JavaScript na makakabasa nito, kaya hindi ito
 * kayang kopyahin at ipadala sa kaklase sa group chat.
 *
 * @return string 32 hex na karakter
 */
function integrity_device_id(mysqli $conn): string
{
    $raw = $_COOKIE[INTEGRITY_COOKIE] ?? '';

    if ($raw !== '' && strpos($raw, '.') !== false) {
        [$id, $sig] = explode('.', $raw, 2);

        if (preg_match('/^[0-9a-f]{32}$/', $id)) {
            $want = substr(hash_hmac('sha256', $id, integrity_secret($conn)), 0, 16);
            // hash_equals — pare-pareho ang tagal ng paghahambing,
            // kaya hindi natututunan ang pirma nang paunti-unti.
            if (hash_equals($want, $sig)) return $id;
        }
    }

    // Wala, sira, o pineke. Bagong ID.
    $id  = bin2hex(random_bytes(16));
    $sig = substr(hash_hmac('sha256', $id, integrity_secret($conn)), 0, 16);

    if (!headers_sent()) {
        $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
              || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');

        setcookie(INTEGRITY_COOKIE, $id . '.' . $sig, [
            'expires'  => time() + 31536000,   // isang taon
            'path'     => '/',
            'secure'   => $https,
            'httponly' => true,
            // Lax at hindi Strict: binubuksan ang link mula sa
            // Messenger o sa camera app na nag-scan ng QR, at sa
            // Strict ay hindi ipinapadala ang cookie sa unang
            // pagdating — bawat estudyante ay magmumukhang bagong
            // device sa tuwing magsisimula.
            'samesite' => 'Lax',
        ]);
    }

    // Isinusulat pabalik sa $_COOKIE para pareho ang sagot ng
    // pangalawang tawag sa loob ng parehong request, kahit hindi pa
    // nakakabalik ang browser dala ang cookie.
    $_COOKIE[INTEGRITY_COOKIE] = $id . '.' . $sig;

    return $id;
}

/**
 * Ang IP ng kliyente, sa likod ng proxy ng hosting.
 *
 * Ang X-Forwarded-For ay kayang i-set ng kahit sino, kaya hindi ito
 * pinagkakatiwalaan para sa paghaharang — pang-talaan lamang, at
 * bilang malaking-bilang na rate limit. Ang unang halaga ang
 * kinukuha: doon nakasulat ang orihinal na kliyente.
 */
function integrity_client_ip(): string
{
    $fwd = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? '';
    if ($fwd !== '') {
        $first = trim(explode(',', $fwd)[0]);
        if (filter_var($first, FILTER_VALIDATE_IP)) return substr($first, 0, 45);
    }

    return substr($_SERVER['REMOTE_ADDR'] ?? '', 0, 45);
}

/**
 * May naisumite na bang IBANG estudyante ang device na ito para sa
 * link na ito ngayong araw?
 *
 * Ito ang buong lakas ng device binding: patay ang "isang telepono,
 * sampung kaklase". Ang sariling pag-uulit ng estudyante ay hindi
 * nito hinuhuli — ang duplicate check sa crud/submit_attendance.php
 * ang bahala roon.
 *
 * @return string|null  student_no ng naunang nagsumite, o null
 */
function integrity_device_conflict(
    mysqli $conn,
    string $device_id,
    string $short_code,
    string $student_no
): ?string {
    if ($device_id === '') return null;

    // try/catch sa paligid ng bawat tanong sa attendance_audit_tbl:
    // ang talaang ito ay dumarating kasama ng isang migration, at ang
    // paaralang nag-upload ng bagong bersyon ngunit hindi pa
    // napapatakbo ang SQL ay may buong klaseng nakatayo sa harap ng
    // pintuan. Ang tampok na hindi pa handa ay dapat PATAY, hindi
    // sagabal — huwag hayaang ang bagong tseke ang siyang humarang sa
    // attendance na gumagana naman noon.
    try {
        $stmt = $conn->prepare("
            SELECT student_no
            FROM attendance_audit_tbl
            WHERE device_id  = ?
              AND short_code = ?
              AND result     = 'ok'
              AND created_at >= CURDATE()
              AND student_no <> ?
            ORDER BY id DESC
            LIMIT 1
        ");
        $stmt->bind_param("sss", $device_id, $short_code, $student_no);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
    } catch (Throwable $e) {
        error_log('integrity_device_conflict: ' . $e->getMessage());
        return null;
    }

    return $row ? $row['student_no'] : null;
}

// ─────────────────────────────────────────────────────────────
// 2. Ang bilangan
// ─────────────────────────────────────────────────────────────

/**
 * Pinapayagan pa ba ang bucket na ito?
 *
 * Isang hilera kada bucket. Kapag lumipas na ang window, ang
 * parehong hilera ang binabalik sa 1 — hindi bagong hilera, kaya
 * hindi lumalaki ang talaan kahit gaano katagal tumakbo.
 *
 * Ang hangganan ay dapat MALUWAG kapag IP ang bucket: isang public
 * IP lamang ang buong silid sa NAT ng paaralan, kaya ang apatnapung
 * estudyanteng naghahanap ng sarili nilang numero ay iisang IP. Ang
 * hinuhuli nito ay ang nag-iiskrip ng dalawang libong numero, hindi
 * ang klase.
 */
function integrity_rate_ok(mysqli $conn, string $bucket, int $limit, int $window_sec): bool
{
    $bucket = substr($bucket, 0, 64);

    // Kapag wala pa ang talaan, PUMAPASA — hindi humaharang. Ang
    // bilangan ay proteksyon laban sa pag-scrape; ang pagpalya nito
    // nang sarado ay pagsasara ng attendance para sa lahat, at mas
    // malaki ang pinsala niyon kaysa sa pinipigilan nito.
    try {
        $up = $conn->prepare("
            INSERT INTO attendance_ratelimit_tbl (bucket, window_start, hits)
            VALUES (?, NOW(), 1)
            ON DUPLICATE KEY UPDATE
                hits         = IF(window_start < DATE_SUB(NOW(), INTERVAL ? SECOND), 1, hits + 1),
                window_start = IF(window_start < DATE_SUB(NOW(), INTERVAL ? SECOND), NOW(), window_start)
        ");
        $up->bind_param("sii", $bucket, $window_sec, $window_sec);
        $up->execute();
        $up->close();

        $sel = $conn->prepare("SELECT hits FROM attendance_ratelimit_tbl WHERE bucket = ?");
        $sel->bind_param("s", $bucket);
        $sel->execute();
        $row = $sel->get_result()->fetch_assoc();
        $sel->close();
    } catch (Throwable $e) {
        error_log('integrity_rate_ok: ' . $e->getMessage());
        return true;
    }

    // Tinatanggal ang mga lumipas nang bucket paminsan-minsan.
    // Hindi kada request: puro sayang na sulat iyon sa isang
    // talaang may ilang dosenang hilera lamang.
    if (random_int(1, 50) === 1) {
        $conn->query("
            DELETE FROM attendance_ratelimit_tbl
            WHERE window_start < DATE_SUB(NOW(), INTERVAL 1 DAY)
        ");
    }

    return ((int) ($row['hits'] ?? 0)) <= $limit;
}


// ─────────────────────────────────────────────────────────────
// 3. Ang talaan
// ─────────────────────────────────────────────────────────────

/**
 * Isinusulat ang kahihinatnan ng isang pagsusumite.
 *
 * Tinatawag ito sa BAWAT labasan ng crud/submit_attendance.php na
 * may kinalaman sa pagkakakilanlan — pati ang mga tinanggihan.
 * Doon nakatago ang balita: ang tatlong 'device_reuse' sa loob ng
 * isang minuto ay hindi hinuha, nakasulat iyon.
 *
 * Hindi kailanman humihinto ang pagsusumite dahil sa file na ito.
 * Tagapagmasid ang audit, hindi bantay — kapag nabigo ang INSERT,
 * tahimik itong dumaraan.
 *
 * ── Ang mga kahihinatnan ────────────────────────────────────
 *
 * Nakalista rito at hindi sa migration: ang migration ay isang
 * petsa na hindi na muling binubuksan, at ang talasalitaang ito ay
 * lumalaki. Ang pages/attendance_integrity.php ang nagbibigay ng
 * label at kulay sa bawat isa; ang hindi kilalang halaga ay
 * lumalabas pa rin doon, kulay-abo, at hindi nawawala.
 *
 *   Ang pumasa
 *     ok             naitala
 *
 *   May pagkukusa — ito ang Flagged
 *     device_reuse   ibang estudyante na ang naisumite ng teleponong ito ngayong araw
 *     lookup_limit   umabot sa hangganan ng paghahanap ng numero
 *     not_enrolled   umiiral ang estudyante, wala lamang sa klaseng ito
 *     no_student     walang ganoong numero sa buong paaralan
 *     bad_link       walang ganoong short_code
 *
 *   Pang-araw-araw na hadlang
 *     duplicate      naitala na siya sa asignaturang ito ngayong araw
 *     link_expired   sarado na ang link nang siya ay dumating
 *     link_off       pinatay ang link
 *     form_locked    nakasara ang buong form
 *     photo_missing  hinihingi ang larawan at wala pa siyang na-upload
 *     save_failed    pumasa sa lahat, at hindi pa rin naitala
 */
function integrity_log(mysqli $conn, array $r): void
{
    // Mga lokal na variable at hindi array offset: hinihingi ng
    // bind_param ang reference, at ang nawawalang susi ay babala sa
    // PHP 8. Iisang lugar ang pagpupuno ng butas.
    $student_no    = (string) ($r['student_no']   ?? '');
    $short_code    = (string) ($r['short_code']   ?? '');
    $subject_name  = $r['subject_name']  ?? null;
    $section       = $r['section']       ?? null;
    $instructor_id = isset($r['instructor_id']) ? (int) $r['instructor_id'] : null;
    $device_id     = $r['device_id']     ?? null;
    $fingerprint   = substr((string) ($r['fingerprint'] ?? ''), 0, 16) ?: null;
    $ip            = $r['ip']            ?? null;
    $user_agent    = substr((string) ($r['user_agent'] ?? ($_SERVER['HTTP_USER_AGENT'] ?? '')), 0, 255);
    $result        = (string) ($r['result'] ?? 'unknown');

    try {
        $stmt = $conn->prepare("
            INSERT INTO attendance_audit_tbl
                (student_no, short_code, subject_name, section, instructor_id,
                 device_id, fingerprint, ip, user_agent, result)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->bind_param(
            "ssssisssss",
            $student_no,
            $short_code,
            $subject_name,
            $section,
            $instructor_id,
            $device_id,
            $fingerprint,
            $ip,
            $user_agent,
            $result
        );
        $stmt->execute();
        $stmt->close();
    } catch (Throwable $e) {
        error_log('integrity_log: ' . $e->getMessage());
        return;
    }

    // Ang pantanggal ng lumang hilera. Paminsan-minsan lamang, gaya
    // ng sa rate limit — at PAGKATAPOS ng INSERT, hindi bago, para
    // hindi kailanman ang pagliligpit ang dahilan ng pagkaantala ng
    // estudyanteng nakatayo sa harap ng pintuan.
    if (random_int(1, 100) === 1) {
        $conn->query("
            DELETE FROM attendance_audit_tbl
            WHERE created_at < DATE_SUB(NOW(), INTERVAL " . INTEGRITY_AUDIT_DAYS . " DAY)
        ");
    }
}
