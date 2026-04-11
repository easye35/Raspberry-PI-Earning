document.addEventListener("DOMContentLoaded", () => {
    const sidebar = document.getElementById("sidebar");
    const toggleBtn = document.getElementById("toggleSidebar");
    const content = document.getElementById("content");

    toggleBtn.addEventListener("click", () => {
        sidebar.classList.toggle("collapsed");
    });

    const sections = {
        home: "<div class='card'><h2>Welcome to EarnBox</h2><p>Your earning dashboard.</p></div>",
        earnapp: "<div class='card'><h2>EarnApp Native</h2><div id='earnapp-data'>Loading...</div></div>",
        containers: "<div class='card'><h2>Containers</h2><div id='container-data'>Loading...</div></div>",
        system: "<div class='card'><h2>System Metrics</h2><div id='system-data'>Loading...</div></div>",
        logins: "<div class='card'><h2>Logins</h2><p>Honeygain, Pawns, EarnApp.</p></div>"
    };

    document.querySelectorAll(".nav a").forEach(link => {
        link.addEventListener("click", () => {
            const section = link.getAttribute("data-section");
            content.innerHTML = sections[section] || "Unknown section";

            if (section === "containers") loadContainers();
            if (section === "system") loadGlances();
            if (section === "earnapp") loadEarnApp();
        });
    });

    content.innerHTML = sections.home;
});
