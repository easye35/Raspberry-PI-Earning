/* --------------------------------------------------
   SYSTEM PAGE
-------------------------------------------------- */

function loadSystemPage() {
    content.innerHTML = `
        <div class="grid grid-3">

            <div class="card glass">
                <div class="card-title">CPU Load</div>
                <div id="cpuLoad" class="card-value neon">--%</div>
            </div>

            <div class="card glass">
                <div class="card-title">Memory Usage</div>
                <div id="memUsage" class="card-value neon">--%</div>
            </div>

            <div class="card glass">
                <div class="card-title">Disk Usage</div>
                <div id="diskUsage" class="card-value neon">--%</div>
            </div>

            <div class="card glass">
                <div class="card-title">Temperature</div>
                <div id="tempValue" class="card-value neon">--°C</div>
            </div>

            <div class="card glass">
                <div class="card-title">Uptime</div>
                <div id="uptimeValue" class="card-value neon">--</div>
            </div>

        </div>
    `;

    fetchSystemStats();
}

/* --------------------------------------------------
   FETCH SYSTEM STATS
-------------------------------------------------- */

function fetchSystemStats() {
    fetch("/api/system")
        .then(res => res.json())
        .then(data => {
            updateSystemCard("cpuLoad", data.cpu + "%");
            updateSystemCard("memUsage", data.memory + "%");
            updateSystemCard("diskUsage", data.disk + "%");
            updateSystemCard("tempValue", data.temperature + "°C");
            updateSystemCard("uptimeValue", formatUptime(data.uptime));
        })
        .catch(err => {
            console.error("System API error:", err);
        });
}

/* --------------------------------------------------
   HELPERS
-------------------------------------------------- */

function updateSystemCard(id, value) {
    const el = document.getElementById(id);
    if (!el) return;

    el.textContent = value;

    // Neon pulse animation
    el.style.transition = "none";
    el.style.transform = "scale(1.1)";
    el.style.textShadow = "0 0 12px #00eaff";

    setTimeout(() => {
        el.style.transition = "transform 0.4s ease, text-shadow 0.4s ease";
        el.style.transform = "scale(1)";
        el.style.textShadow = "";
    }, 80);
}

function formatUptime(seconds) {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);

    return `${d}d ${h}h ${m}m`;
}
