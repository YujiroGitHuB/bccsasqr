<?php if (isset($_SESSION['alert'])): ?>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
Swal.fire({
    icon: '<?= $_SESSION['alert']['icon'] ?>',
    title: '<?= $_SESSION['alert']['title'] ?>',
    text: '<?= $_SESSION['alert']['text'] ?>',
    position: '<?= $_SESSION['alert']['position'] ?>',
    confirmButtonText: 'OK',                       // Always show confirm button
    confirmButtonColor: '<?= $_SESSION['alert']['confirmButtonColor'] ?? "#38bdf8" ?>',
    background: '#1e293b',
    color: '#fff'
}).then(() => {
    <?php if (!empty($_SESSION['alert']['redirect'])): ?>
        window.location.href = '<?= $_SESSION['alert']['redirect'] ?>';
    <?php endif; ?>
});
</script>
<?php unset($_SESSION['alert']); endif; ?>
