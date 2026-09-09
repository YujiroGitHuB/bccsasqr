// integrityFilters.js — nagsasalain nang hindi hinihintay ang Apply
//
// Ang salaan ay nasa URL, at sinasadya iyon: ang natuklasan mo ay
// ipinapadala mo sa kapwa guro, at ang link na binubuksan nila ay
// dapat parehong tanawin. Kaya ito ay TOTOONG pagsusumite ng form at
// hindi pagsasala sa loob ng browser — ang bumabalik ay bagong
// pahina na may bagong bilang, bagong pagbibilang ng device, at
// bagong pagination. Ang pagsasala sa harap lamang ay magsisinungaling
// sa lima sa mga iyon.
//
// Ang kapalit ng totoong pagsusumite ay ang reload, at dalawang bagay
// ang binabantayan nito:
//
//   1. Ang paghihintay bago magsumite. Ang bawat titik ay hindi isang
//      pahina — 450ms pagkatapos mong huminto.
//   2. Ang kursor. Pagkatapos ng reload ay nawawala ang pokus at
//      bumabalik ang caret sa umpisa, at ang susunod mong titik ay
//      napupunta sa harap ng tinipa mo. Ibinabalik ito rito.

(function () {
    const form = document.querySelector('.ati-filters');
    if (!form) return;

    const select = form.querySelector('select[name="class"]');
    const search = form.querySelector('input[name="q"]');
    const apply  = form.querySelector('.ati-go');

    // Itinatago lamang kapag TUMATAKBO ang file na ito. Sa browser na
    // walang JavaScript ay nananatili ang pindutan, at gumagana pa rin
    // ang buong pahina sa pamamagitan nito.
    if (apply) apply.hidden = true;
    form.classList.add('is-auto');

    // Ang halagang huling ipinadala sa server. Ang paghahambing dito
    // ang pumipigil sa pagsusumiteng walang ipinagbago — pagpindot sa
    // kahon, pag-alis, pagbalik.
    const sent = search ? search.value : '';

    let timer = null;

    function submitNow() {
        clearTimeout(timer);

        // Ang blangkong q ay tinatanggal sa halip na ipadala bilang
        // "q=": ang URL na ipinapadala mo sa iba ay hindi dapat may
        // dalang salaang wala namang laman.
        if (search && search.value.trim() === '') search.disabled = true;

        form.classList.add('is-working');
        form.submit();
    }

    if (select) {
        // Walang paghihintay: ang pagpili sa dropdown ay tapos na
        // kaagad, at walang darating pang ikalawang pagpili.
        select.addEventListener('change', submitNow);
    }

    if (search) {
        search.addEventListener('input', () => {
            clearTimeout(timer);
            timer = setTimeout(() => {
                if (search.value.trim() !== sent.trim()) submitNow();
            }, 450);
        });

        // Ang Enter ay hindi naghihintay. (Ang form ay magsusumite rin
        // nang mag-isa, pero kailangan pa ring linisin ang blangkong q
        // at patayin ang naghihintay na timer.)
        search.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                submitNow();
            }
        });

        // ── Ang kursor pagkatapos ng reload ──────────────────────
        // Ibinabalik lamang kapag may hinahanap: kung hindi, ang
        // keyboard ng telepono ay bubukas sa tuwing bubuksan ang
        // pahina, at hindi iyon hiniling ninuman.
        if (search.value !== '') {
            search.focus({ preventScroll: true });
            const end = search.value.length;
            try {
                search.setSelectionRange(end, end);
            } catch (err) {
                // Ang ilang uri ng input ay hindi pumapayag nito.
                // Ang pokus ang mahalaga; ang caret ay dagdag.
            }
        }
    }
})();
