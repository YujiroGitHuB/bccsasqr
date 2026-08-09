particlesJS("particles-js", {
    particles: {
        number: {
            value: 6,
            density: {
                enable: true,
                value_area: 800
            }
        },
        color: {
            value: "#1b1e34"
        },
        shape: {
            type: "polygon",
            polygon: {
                nb_sides: 6
            }
        },
        opacity: {
            value: 0.3,
            random: true
        },
        size: {
            value: 160,
            anim: {
                enable: true,
                speed: 10,
                size_min: 40
            }
        },
        move: {
            enable: true,
            speed: 8
        }
    },
    retina_detect: true
});

var stats = new Stats();
stats.showPanel(0);
document.body.appendChild(stats.dom);

var count_particles = document.querySelector(".js-count-particles");

function update() {
    stats.begin();
    stats.end();

    if (window.pJSDom.length > 0) {
        count_particles.innerText =
            window.pJSDom[0].pJS.particles.array.length;
    }

    requestAnimationFrame(update);
}

requestAnimationFrame(update);