document.getElementById("profileForm").addEventListener("submit", function(e) {
    e.preventDefault();

    let formData = new FormData(this);

    fetch("../crud/updateProfile.php", {
        method: "POST",
        body: formData
    })
    .then(res => res.json())
    .then(data => {

        Swal.fire({
            toast: true,
            position: "top-end",
            icon: data.status,
            title: data.message,
            showConfirmButton: false,
            timer: 2000,
            background: "#1f1f1f",
            color: "#fff"
        });

    })
    .catch(err => {
        Swal.fire({
            icon: "error",
            title: "Error",
            text: "Something went wrong."
        });
    });

});
