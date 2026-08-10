// Mas kaunting particles sa maliliit na screen para mas magaan sa mobile
var isSmallScreen = window.matchMedia("(max-width: 576px)").matches;
var prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

particlesJS("particles-js", {
    particles: {
        number: {
            value: isSmallScreen ? 3 : 6,
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
            value: isSmallScreen ? 110 : 160,
            anim: {
                enable: !prefersReducedMotion,
                speed: 10,
                size_min: 40
            }
        },
        move: {
            enable: !prefersReducedMotion,
            speed: isSmallScreen ? 4 : 8
        }
    },
    // Retina rendering sa mobile = 2-3x na pixels na iginuguhit kada frame
    retina_detect: !isSmallScreen
});
