function comingSoon() {
    Swal.fire({
        toast: true,
        position: 'top-end',
        icon: 'info',
        title: 'This feature is currently under development. Stay tuned for upcoming updates!',
        showConfirmButton: false,
        timer: 2000,
        timerProgressBar: true
    });
}