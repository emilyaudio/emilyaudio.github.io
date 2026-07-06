// Light/dark theme toggle, shared by every page. Sets data-theme on <html>;
// CSS in base.css does the rest. The choice persists in localStorage; the
// inline head snippet on each page restores it before paint (this file is
// deferred, so it can't restore without a flash).
(function () {
    var btn = document.getElementById("themeBtn"),
        root = document.documentElement;
    if (!btn) return;
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
