<?php
// ============================================================
// The Android app on the download page: which version it is, and
// the oldest build still allowed to run.
//
// The APK is uploaded by hand (download/BCC-SASQR.apk — see
// download/index.php), so its version is READ FROM THE FILE rather
// than written here: whatever is uploaded is what the phones are told
// about, and there is no number to keep in step with it. The app asks
// GET /api/v1/app when it starts and when it comes back to the
// screen, and offers the update when this build is newer than its own.
//
// Until 2026-10-02 an installed app never knew it was out of date —
// there is no store to tell it — so a student kept whichever build
// they first downloaded.
// ============================================================

/**
 * The oldest app build (versionCode — the number after the + in
 * pubspec.yaml) still allowed to run. A phone with an older build
 * shows only "Update required" and the way to the download page.
 *
 * Raise it only when a change on the server breaks older builds — a
 * route removed, or answering differently — and only once the new APK
 * is uploaded, or the phones are sent to download what they already
 * have. 0 stops no one.
 */
const APP_MIN_BUILD = 0;

/** The file download/index.php offers. */
const APP_APK_FILE = __DIR__ . '/../download/BCC-SASQR.apk';

/**
 * The uploaded app — its version, build, size and when it was
 * uploaded — or null when there is no APK, or it cannot be read.
 *
 * @return array{version: string, build: int, size: int, updated: int}|null
 */
function app_release(): ?array
{
    static $read = false;
    static $release = null;
    if ($read) {
        return $release;
    }
    $read = true;

    if (!is_file(APP_APK_FILE) || !class_exists('ZipArchive')) {
        return null;
    }

    $zip = new ZipArchive();
    if ($zip->open(APP_APK_FILE) !== true) {
        error_log('[app_release] cannot open ' . APP_APK_FILE);
        return null;
    }
    $manifest = $zip->getFromName('AndroidManifest.xml');
    $zip->close();

    $version = is_string($manifest) ? app_manifest_version($manifest) : null;
    if ($version === null) {
        error_log('[app_release] no version in the APK manifest');
        return null;
    }

    return $release = $version + [
        'size'    => (int) filesize(APP_APK_FILE),
        'updated' => (int) filemtime(APP_APK_FILE),
    ];
}

/**
 * versionName and versionCode from an APK's AndroidManifest.xml.
 *
 * Inside an APK the manifest is not text but Android's compiled XML:
 * a string pool, the resource ids of the attribute names, then the
 * elements as binary chunks. Only the first element — <manifest> —
 * is read. Every offset is checked, so a damaged file answers null
 * rather than a warning.
 *
 * @return array{version: string, build: int}|null
 */
function app_manifest_version(string $xml): ?array
{
    $len = strlen($xml);
    $u16 = static fn(int $at): ?int => $at >= 0 && $at + 2 <= $len ? unpack('v', $xml, $at)[1] : null;
    $u32 = static fn(int $at): ?int => $at >= 0 && $at + 4 <= $len ? unpack('V', $xml, $at)[1] : null;

    if ($u16(0) !== 0x0003) {   // RES_XML_TYPE: a compiled XML file
        return null;
    }

    $strings = [];
    $resIds  = [];
    $at      = (int) $u16(2);   // past the file's own header

    while ($at + 8 <= $len) {
        $type = $u16($at);
        $head = (int) $u16($at + 2);
        $size = (int) $u32($at + 4);
        if ($size < 8 || $at + $size > $len) {
            return null;
        }

        if ($type === 0x0001) {
            $strings = app_axml_strings($xml, $at, $head, $u16, $u32);
        } elseif ($type === 0x0180) {
            // The resource id of each attribute name, by string index —
            // how an attribute is known when its name was stripped.
            for ($o = $at + $head; $o + 4 <= $at + $size; $o += 4) {
                $resIds[] = $u32($o);
            }
        } elseif ($type === 0x0102) {
            return app_axml_manifest_version($at + $head, $strings, $resIds, $xml, $u16, $u32);
        }

        $at += $size;
    }

    return null;
}

/** The string pool chunk at $at, as UTF-8 strings by index. */
function app_axml_strings(string $xml, int $at, int $head, callable $u16, callable $u32): array
{
    $count = (int) $u32($at + 8);
    $utf8  = (((int) $u32($at + 16)) & 0x100) !== 0;
    $start = $at + (int) $u32($at + 20);
    $len   = strlen($xml);

    $strings = [];
    for ($i = 0; $i < $count; $i++) {
        $offset = $u32($at + $head + $i * 4);
        if ($offset === null) {
            break;
        }
        $o = $start + $offset;
        if ($o < 0 || $o + 2 > $len) {
            continue;
        }

        if ($utf8) {
            // The length in characters, then in bytes — each one or two bytes.
            $o += (ord($xml[$o]) & 0x80) ? 2 : 1;
            if ($o + 1 > $len) {
                continue;
            }
            $bytes = ord($xml[$o]);
            if ($bytes & 0x80) {
                $bytes = (($bytes & 0x7f) << 8) | ord($xml[$o + 1] ?? "\0");
                $o += 2;
            } else {
                $o += 1;
            }
            $strings[$i] = (string) substr($xml, $o, $bytes);
        } else {
            $chars = (int) $u16($o);
            $o += 2;
            if ($chars & 0x8000) {
                $chars = (($chars & 0x7fff) << 16) | (int) $u16($o);
                $o += 2;
            }
            $raw = (string) substr($xml, $o, $chars * 2);
            $strings[$i] = function_exists('mb_convert_encoding')
                ? mb_convert_encoding($raw, 'UTF-8', 'UTF-16LE')
                // Without mbstring: enough for the plain ASCII a version is.
                : preg_replace('/(.)\x00/s', '$1', $raw);
        }
    }

    return $strings;
}

/**
 * versionCode and versionName off the <manifest> start element whose
 * attribute extension begins at $ext.
 */
function app_axml_manifest_version(int $ext, array $strings, array $resIds, string $xml, callable $u16, callable $u32): ?array
{
    if (($strings[(int) $u32($ext + 4)] ?? '') !== 'manifest') {
        return null;
    }

    $first = (int) $u16($ext + 8);
    $size  = (int) $u16($ext + 10);
    $count = (int) $u16($ext + 12);

    $build   = null;
    $version = null;
    for ($i = 0; $i < $count; $i++) {
        $a = $ext + $first + $i * $size;
        $nameIndex = $u32($a + 4);
        $raw       = $u32($a + 8);
        $dataType  = $a + 15 < strlen($xml) ? ord($xml[$a + 15]) : null;
        $data      = $u32($a + 16);
        if ($nameIndex === null || $data === null) {
            return null;
        }

        // By name, or by the framework's id when the name was stripped.
        $name = $strings[$nameIndex] ?? '';
        $id   = $resIds[$nameIndex] ?? 0;

        if ($name === 'versionCode' || $id === 0x0101021b) {
            $build = ($dataType === 0x10 || $dataType === 0x11)
                ? $data
                : (ctype_digit($strings[$raw] ?? '') ? (int) $strings[$raw] : null);
        } elseif ($name === 'versionName' || $id === 0x0101021c) {
            $version = $raw !== 0xFFFFFFFF
                ? ($strings[$raw] ?? null)
                : ($dataType === 0x03 ? ($strings[$data] ?? null) : null);
        }
    }

    if ($build === null) {
        return null;
    }

    return ['version' => (string) ($version ?? (string) $build), 'build' => (int) $build];
}
