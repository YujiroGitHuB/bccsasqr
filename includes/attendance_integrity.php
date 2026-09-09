<?php
// ============================================================
// Kung sino ang may hawak ng telepono, sa isang lugar.
//
// Ang includes/photo_requirement.php ay isinulat dahil naghiwalay
// ang dalawang pintuan ng attendance — ang scanner at ang link —
// at ang tuntuning ipinatupad ng isa ay hindi alam ng isa. Ganoon
// din ang dahilan ng file na ito. Anim na bagay ang hinahawakan:
//
//   1. device_id     — ang cookie na nagsasabing iisang telepono
//   2. rate limit    — ang bilangan ng paghahanap ng numero
//   3. audit         — ang talaan ng bawat pagsusumite
//   4. room code     — ang umiikot na anim na digit sa harapan
//   5. selfie        — ang paminsan-minsang hiling ng mukha
//   6. lihim         — ang HMAC key na ginagamit ng 1, 4 at 5
//
// Tatlong file ang tumatawag nito: crud/verify_student.php,
// crud/submit_attendance.php at crud/room_code.php. Kung
// maghihiwalay silang muli, ang butas ay bubukas sa pinakamaluwag
// sa tatlo — gaya ng nangyari sa larawan.
//
// Walang tinatanggihan ang file na ito nang mag-isa. Nagsasagot
// lamang ito ng tanong; ang tumatawag ang nagpapasya.
// ============================================================

const INTEGRITY_COOKIE     = 'bcc_did';
const INTEGRITY_ROOM_STEP  = 30;      // segundo kada code
const INTEGRITY_AUDIT_DAYS = 30;      // gaano katagal itinatago ang talaan
const INTEGRITY_SELFIE_MAX = 400000;  // bytes, matapos i-decode (~400KB)


// ─────────────────────────────────────────────────────────────
// 6. Ang lihim
// ─────────────────────────────────────────────────────────────

/**
 * Ang HMAC key ng buong file na ito.
 *
 * Nauuna ang INTEGRITY_SECRET sa includes/config.php kapag
 * itinakda — doon dapat ito sa isang tunay na deployment, dahil
 * hindi nakikita ng sinumang nakakabasa ng database ang file na
 * iyon. Kapag wala, gumagawa ito ng isa at itinatago sa
 * attendance_settings, para hindi kailangang mag-edit ng file ang
 * paaralang nag-a-upload lamang ng bagong bersyon sa hosting.
 *
 * Ang pagpapalit nito ay pagpapawalang-bisa ng lahat ng device
 * cookie at ng lahat ng bukas na room code — walang mawawalang
 * attendance, magsisimula lamang muli ang pagkilala sa device.
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
 * determinado ang dahilan kung bakit may audit trail at may selfie
 * spot check.
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

/**
 * Ilang MAGKAKAIBANG estudyante ang naisumite ng device na ito sa
 * nakaraang pitong araw, sa lahat ng link?
 *
 * Ang isang beses ay maaaring hiniram na telepono ng kaklaseng
 * naubusan ng baterya. Ang tatlo sa loob ng isang linggo ay hindi
 * na iyon. Ginagamit ito para pumili ng hihingan ng selfie, hindi
 * para humarang: totoo rin ang magkapatid na iisa ang telepono.
 */
function integrity_device_reach(mysqli $conn, string $device_id): int
{
    if ($device_id === '') return 0;

    // Gaya ng integrity_device_conflict(): patay ang tampok kapag
    // wala pa ang talaan, hindi sagabal.
    try {
        $stmt = $conn->prepare("
            SELECT COUNT(DISTINCT student_no) AS n
            FROM attendance_audit_tbl
            WHERE device_id  = ?
              AND result     = 'ok'
              AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ");
        $stmt->bind_param("s", $device_id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
    } catch (Throwable $e) {
        error_log('integrity_device_reach: ' . $e->getMessage());
        return 0;
    }

    return (int) ($row['n'] ?? 0);
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
    $selfie_path   = $r['selfie_path']   ?? null;
    $result        = (string) ($r['result'] ?? 'unknown');

    try {
        $stmt = $conn->prepare("
            INSERT INTO attendance_audit_tbl
                (student_no, short_code, subject_name, section, instructor_id,
                 device_id, fingerprint, ip, user_agent, selfie_path, result)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->bind_param(
            "ssssissssss",
            $student_no,
            $short_code,
            $subject_name,
            $section,
            $instructor_id,
            $device_id,
            $fingerprint,
            $ip,
            $user_agent,
            $selfie_path,
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


// ─────────────────────────────────────────────────────────────
// 4. Ang code ng silid
// ─────────────────────────────────────────────────────────────

/**
 * Anim na digit para sa isang yugto ng panahon.
 *
 * Ang binhi ay nasa database, ang code ay hindi kailanman —
 * kinakalkula ito kada tanong. Kaya walang matatagpuang listahan ng
 * darating na code kahit sa mismong talaan.
 */
function room_code_at(string $secret, int $window): string
{
    $mac = hash_hmac('sha256', (string) $window, $secret);

    // Anim na hex na digit → hanggang 16.7M, tapos modulo 1M. Ang
    // bahagyang hilig sa mababang numero ay walang saysay dito:
    // tatlumpung segundo lamang ang buhay ng bawat code.
    return str_pad((string) (hexdec(substr($mac, 0, 6)) % 1000000), 6, '0', STR_PAD_LEFT);
}

/** Ang kasalukuyang yugto. */
function room_code_window(): int
{
    return (int) floor(time() / INTEGRITY_ROOM_STEP);
}

/**
 * Tama ba ang tinipa ng estudyante?
 *
 * Tinatanggap ang kasalukuyang yugto AT ang nakaraan. Tatlumpung
 * segundo ang bawat isa, kaya ang taong nagsimulang tumipa sa
 * ikadalawampu't-siyam na segundo ay may buong tatlumpung segundo
 * pang natitira — hindi siya dapat parusahan dahil mabagal ang
 * daliri niya o ang koneksyon.
 */
function room_code_valid(string $secret, string $input): bool
{
    $input = preg_replace('/\D/', '', $input);
    if (strlen($input) !== 6) return false;

    $now = room_code_window();

    foreach ([$now, $now - 1] as $w) {
        if (hash_equals(room_code_at($secret, $w), $input)) return true;
    }

    return false;
}

/**
 * Ang binhi ng isang link, ginagawa kapag wala pa.
 *
 * Tinatawag kapag binuksan ang tampok para sa link na iyon at kapag
 * hinihingi ng instruktor ang live na code. Hindi kailanman
 * ipinapadala sa browser ng estudyante — kung naroon ito, kayang
 * kalkulahin ng sinuman ang code mula sa bahay.
 */
function room_code_secret(mysqli $conn, string $short_code): ?string
{
    // null kapag wala pa ang column — hindi pa napapatakbo ang
    // migration, kaya hindi pa umiiral ang tampok. Ang tumatawag ay
    // magsasabing hindi ito mabuksan, at ang attendance ay
    // magpapatuloy nang wala ito.
    $read = function () use ($conn, $short_code) {
        try {
            $stmt = $conn->prepare("SELECT room_code_secret FROM attendance_links_tbl WHERE short_code = ?");
            $stmt->bind_param("s", $short_code);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            return $row;
        } catch (Throwable $e) {
            error_log('room_code_secret: ' . $e->getMessage());
            return null;
        }
    };

    $row = $read();
    if (!$row) return null;
    if (!empty($row['room_code_secret'])) return $row['room_code_secret'];

    $secret = bin2hex(random_bytes(32));

    try {
        $upd = $conn->prepare("
            UPDATE attendance_links_tbl SET room_code_secret = ?
            WHERE short_code = ? AND room_code_secret IS NULL
        ");
        $upd->bind_param("ss", $secret, $short_code);
        $upd->execute();
        $upd->close();
    } catch (Throwable $e) {
        error_log('room_code_secret: ' . $e->getMessage());
        return null;
    }

    // Muling basahin: kapag may naunang request na nakapagtakda na,
    // ang kanila ang totoo — hindi ang bagong ginawa rito. Kung
    // hindi, ang isang instruktor ay magpapakita ng code na hindi
    // tinatanggap ng server.
    $row = $read();

    return $row['room_code_secret'] ?? $secret;
}


// ─────────────────────────────────────────────────────────────
// 5. Ang selfie
// ─────────────────────────────────────────────────────────────

/**
 * Hihingan ba ng selfie ang pagsusumiteng ito?
 *
 * Dalawang dahilan:
 *
 *   1. Napili siya ng spot check. DETERMINISTIKO ang pagpili — ang
 *      parehong estudyante sa parehong link sa parehong araw ay
 *      laging pareho ang sagot. Kung random ito kada request, ang
 *      tanging kailangang gawin ay mag-refresh hanggang hindi ka na
 *      tanungin, at wala nang saysay ang buong tampok.
 *
 *   2. Marami nang estudyanteng naisumite ang device na ito
 *      kamakailan. Hindi ito humaharang — nagtatanong lamang, at
 *      ang mukha ang sasagot.
 *
 * Ang bahagdan ay galing sa Settings. 0 = patay ang tampok.
 */
function selfie_is_required(
    mysqli $conn,
    string $student_no,
    string $short_code,
    int $rate,
    int $device_reach
): bool {
    // Ang device na nakapagsumite na para sa tatlong magkakaibang
    // tao ngayong linggo ay tinatanong kahit patay ang spot check:
    // ito ang mismong huwarang hinahanap ng tampok.
    if ($device_reach >= 3) return true;

    if ($rate <= 0)   return false;
    if ($rate >= 100) return true;

    $seed = $student_no . '|' . $short_code . '|' . date('Y-m-d') . '|' . integrity_secret($conn);

    return (hexdec(substr(hash('sha256', $seed), 0, 6)) % 100) < $rate;
}

/**
 * Isinusulat ang selfie sa uploads/ at isinasauli ang path nito.
 *
 * Sa disk at hindi sa database: sampung megabyte lamang ang
 * database, at ang isang larawan ay kasinlaki ng isang libong
 * hilera ng attendance.
 *
 * Sinusuri kung larawan nga ito bago isulat — hindi ang sinasabi ng
 * data URL kundi ang mismong nilalaman, dahil ang unahan ng data
 * URL ay isinulat ng kliyente.
 *
 * @return array{path:?string,error:?string}
 */
function selfie_store(string $data_url, string $student_no): array
{
    $fail = fn(string $msg) => ['path' => null, 'error' => $msg];

    if (strpos($data_url, 'base64,') === false) {
        return $fail('Photo was not sent correctly. Please try again.');
    }

    $bin = base64_decode(substr($data_url, strpos($data_url, 'base64,') + 7), true);

    if ($bin === false || $bin === '') {
        return $fail('Photo was not sent correctly. Please try again.');
    }

    if (strlen($bin) > INTEGRITY_SELFIE_MAX) {
        return $fail('Photo is too large. Please try again.');
    }

    $info = @getimagesizefromstring($bin);
    if ($info === false || !in_array($info[2], [IMAGETYPE_JPEG, IMAGETYPE_PNG, IMAGETYPE_WEBP], true)) {
        return $fail('That file is not a photo.');
    }

    // Isang folder kada araw: madaling tingnan ang isang sesyon, at
    // madaling tanggalin ang isang buwan nang buo.
    $day = date('Y-m-d');
    $dir = __DIR__ . '/../uploads/selfies/' . $day;

    if (!is_dir($dir) && !@mkdir($dir, 0755, true) && !is_dir($dir)) {
        return $fail('Could not save the photo. Please contact your instructor.');
    }

    // May gitling ang student_no ("025-1114") — pinapayagan iyon,
    // ang iba ay hindi, kaya walang makakalabas sa folder na ito
    // sa pamamagitan ng numerong may "../".
    $safe = preg_replace('/[^A-Za-z0-9\-]/', '', $student_no);
    $name = $safe . '_' . date('His') . '_' . bin2hex(random_bytes(3)) . '.jpg';

    if (@file_put_contents($dir . '/' . $name, $bin) === false) {
        return $fail('Could not save the photo. Please contact your instructor.');
    }

    return ['path' => 'uploads/selfies/' . $day . '/' . $name, 'error' => null];
}
