// Light/dark theme toggle, shared by every page. Sets data-theme on <html>;
// CSS in base.css does the rest. No persistence -- matches the page default
// until the visitor clicks.
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
        root.setAttribute("data-theme", isDark() ? "light" : "dark");
        sync();
    });
})();
