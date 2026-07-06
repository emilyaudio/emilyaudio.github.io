// Light/dark theme toggle, shared by every page. Sets data-theme on <html>;
// CSS in base.css does the rest. The choice persists in localStorage; the
// inline head snippet on each page restores it before paint (this file is
// deferred, so it can't restore without a flash).
(function () {
    var btn = document.getElementById("themeBtn"),
        root = document.documentElement;
    if (!btn) {
        return;
    }
    function isDark() {
        return (
            (root.getAttribute("data-theme") ||
                (matchMedia("(prefers-color-scheme: dark)").matches
                    ? "dark"
                    : "light")) === "dark"
        );
    }
    function sync() {
        btn.setAttribute("aria-pressed", isDark());
    }
    sync();
    btn.addEventListener("click", function () {
        var next = isDark() ? "light" : "dark";
        root.setAttribute("data-theme", next);
        localStorage.setItem("theme", next);
        sync();
    });
})();

// Video cards, shared by /vo and /audio (no-op on pages without .vmedia).
// Click the overlay to play in place with sound; on capable pointers a muted
// preview runs on hover. Cards are independent -- no cross-card coordination.
(function () {
    function fmtDur(t) {
        if (!isFinite(t)) {
            return "";
        }
        var mm = Math.floor(t / 60),
            ss = Math.floor(t % 60);
        return mm + ":" + (ss < 10 ? "0" : "") + ss;
    }
    var canHoverPreview =
        matchMedia("(hover: hover)").matches &&
        matchMedia("(prefers-reduced-motion: no-preference)").matches;
    document.querySelectorAll(".vmedia").forEach(function (m) {
        var v = m.querySelector("video"),
            b = m.querySelector(".vplay"),
            dur = m.querySelector(".vdur");
        var clicked = false; // true once the user clicks to play with sound.
        function setDur() {
            if (dur) {
                dur.textContent = fmtDur(v.duration);
            }
        }
        v.addEventListener("loadedmetadata", setDur);
        if (v.readyState >= 1) {
            setDur();
        }

        b.addEventListener("click", function () {
            clicked = true;
            v.muted = false;
            v.currentTime = 0;
            v.controls = true;
            v.play();
        });
        v.addEventListener("play", function () {
            if (clicked) {
                m.classList.add("playing");
                b.tabIndex = -1;
            }
        });
        v.addEventListener("pause", function () {
            // A user pause mid-clip (native controls) must stay paused-in-place
            // so play resumes where it left off -- don't tear the controls
            // down. Only hover-preview pauses (clicked === false) reset the
            // poster.
            if (clicked) {
                return;
            }
            m.classList.remove("playing");
            v.controls = false;
            b.tabIndex = 0;
        });
        v.addEventListener("ended", function () {
            m.classList.remove("playing");
            v.controls = false;
            clicked = false;
            b.tabIndex = 0;
        });

        if (canHoverPreview) {
            m.addEventListener("mouseenter", function () {
                if (clicked || !v.paused) {
                    return;
                }
                v.muted = true;
                v.play().catch(function () {});
            });
            m.addEventListener("mouseleave", function () {
                if (clicked) {
                    return;
                }
                v.pause();
                v.load(); // load() restores the poster.
            });
        }
    });
})();
