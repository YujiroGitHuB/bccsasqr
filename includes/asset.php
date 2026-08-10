<?php
/*
 * ============================================================
 * Awtomatikong cache-busting para sa lokal na CSS at JS.
 *
 * Ang problema: ini-cache ng browser ang main.css at mga script.
 * Kapag nag-deploy tayo ng ayos sa CSS, luma pa rin ang nakikita ng
 * mga gumagamit — lalo na sa telepono kung saan matagal nananatili
 * ang cache. Ang lunas noon ay manwal na "?v=1.2", pero kailangan
 * itong tandaang baguhin sa tuwing may edit; kapag nakalimutan,
 * walang nakikitang pagbabago.
 *
 * Dito, ang oras ng huling pagbabago ng file (filemtime) ang bersyon.
 * Ganito ito ginagamit sa loob ng isang PHP echo tag:
 *
 *     <link rel="stylesheet" href="{asset('../assets/css/main.css')}">
 *
 * at ang inilalabas nito ay:
 *
 *     ../assets/css/main.css?v=1770712345
 *
 * Kapag nag-iba ang file, nag-iba ang numero, at kusang kukuha ng
 * bago ang browser. Kapag hindi, mananatili ang cache — walang
 * nasasayang na request.
 *
 * Ang ipinapasa ay ang HREF mismo na nakasulat sa HTML (kasama ang
 * mga "../"). Ang ganoong path ay sinusukat ng browser laban sa URL
 * ng page, at ang katumbas nito sa disk ay ang folder ng script na
 * tumatakbo — kaya SCRIPT_FILENAME ang batayan natin. Gumagana ito
 * kahit saang lalim ang page (index.php, pages/…, Qrscanner/…).
 *
 * TANDA: huwag maglagay ng PHP closing tag sa loob ng "//" na
 * komento dito — tinatapos noon ang PHP mode kahit komento pa iyon,
 * at hindi na mababasa ang function sa ibaba.
 * ============================================================
 */

if (!function_exists('asset')) {

    function asset(string $href): string
    {
        // Isang beses lang kada request ang stat sa bawat file —
        // ilang beses ini-include ang ilang script kada page.
        static $cache = [];

        if (isset($cache[$href])) {
            return $cache[$href];
        }

        // Tanggalin ang anumang lumang "?v=…" na nakasulat pa sa HTML.
        $path = strtok($href, '?');

        $base = isset($_SERVER['SCRIPT_FILENAME'])
            ? dirname($_SERVER['SCRIPT_FILENAME'])
            : dirname(__DIR__);

        $mtime = @filemtime($base . '/' . $path);

        // Kapag hindi makita ang file (halimbawa, ibang setup ng
        // hosting), ibinabalik ang orihinal na path — mas mabuti nang
        // walang bersyon kaysa sirang link.
        return $cache[$href] = $mtime ? $path . '?v=' . $mtime : $path;
    }
}
