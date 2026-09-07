<?php
// ============================================================
//  api/v1/lib/rate_limit.php
//
//  Bakit kailangan ito ng API at hindi ng web page.
//
//  Ang lookup ng estudyante ay bukas sa lahat — kailangan, dahil
//  hindi nagla-log in ang estudyante bago kumuha ng QR. Sa browser,
//  isang tao ang nagta-type ng student number nang paisa-isa. Sa
//  isang HTTP client, ang parehong endpoint ay maaaring tawagin nang
//  libo-libong beses kada minuto hanggang malaman ng tumatawag kung
//  aling student number ang totoo — at kasama ang pangalan, kurso at
//  seksyon sa bawat tama.
//
//  Ito ang preno: mabagal para sa manghuhula, hindi mahahalata ng
//  estudyanteng nagta-type ng sariling numero.
//
//  Nasa temp directory ang mga counter at hindi sa loob ng proyekto:
//  read-only ang web root sa ilang host, at hindi dapat mahulog ang
//  isang estudyante dahil lang doon.
// ============================================================

/**
 * Allows $max requests per $seconds for one IP + bucket.
 *
 * Fails open. A rate limiter that cannot write its counter must not
 * be the reason a student cannot get their QR code — the limit is a
 * courtesy, the generator is the product.
 */
function api_rate_limit(string $bucket, int $max, int $seconds): void
{
    $dir = rtrim(sys_get_temp_dir(), '/\\') . DIRECTORY_SEPARATOR . 'bcc_api_rl';

    if (!is_dir($dir) && !@mkdir($dir, 0777, true) && !is_dir($dir)) {
        return;
    }

    $file = $dir . DIRECTORY_SEPARATOR . md5($bucket . '|' . api_client_ip()) . '.json';
    $now  = time();

    $fh = @fopen($file, 'c+');
    if (!$fh) {
        return;
    }

    if (!@flock($fh, LOCK_EX)) {
        fclose($fh);
        return;
    }

    $state = json_decode((string) stream_get_contents($fh), true);

    // A window that has run out starts a fresh one rather than
    // sliding — simpler, and the difference does not matter at this
    // resolution.
    if (!is_array($state) || !isset($state['start'], $state['count']) || $now - (int) $state['start'] >= $seconds) {
        $state = ['start' => $now, 'count' => 0];
    }

    $state['count'] = (int) $state['count'] + 1;
    $overLimit      = $state['count'] > $max;
    $retryAfter     = max(1, $seconds - ($now - (int) $state['start']));

    ftruncate($fh, 0);
    rewind($fh);
    fwrite($fh, json_encode($state));
    fflush($fh);
    flock($fh, LOCK_UN);
    fclose($fh);

    // One file in a hundred sweeps the directory, so abandoned
    // counters do not pile up on a long-lived server.
    if (random_int(1, 100) === 1) {
        api_rate_limit_sweep($dir, $seconds);
    }

    if ($overLimit) {
        header('Retry-After: ' . $retryAfter);
        api_fail(429, 'rate_limited', 'Too many requests. Please wait a moment and try again.', [
            'retry_after' => $retryAfter,
        ]);
    }
}

/** Deletes counter files whose window closed long ago. */
function api_rate_limit_sweep(string $dir, int $seconds): void
{
    $cutoff = time() - max(3600, $seconds * 4);

    foreach ((array) @glob($dir . DIRECTORY_SEPARATOR . '*.json') as $old) {
        if (@filemtime($old) < $cutoff) {
            @unlink($old);
        }
    }
}
