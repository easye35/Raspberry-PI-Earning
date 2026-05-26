// -------------------------------------------------------------
// Backend API base URL (dynamic, no static IP)
// -------------------------------------------------------------
const API = `http://${window.location.hostname}:3001`;

// -------------------------------------------------------------
// Modal state
// -------------------------------------------------------------
let logsOpen = false;

// -------------------------------------------------------------
// Utility: Smooth number update
// -------------------------------------------------------------
function smoothUpdate(element, newValue, suffix = "") {
    if (!element) return;
    element.textContent = `${newValue}${suffix}`;
}

// -------------------------------------------------------------
// Loading placeholders
// -------------------------------------------------------------
function showLoading() {
    smoothUpdate(document.getElementById("cpuValue"), "…");
    smoothUpdate(document.getElementById("ramValue"), "…");
    smoothUpdate(document.getElementById("diskValue"), "…");
    const netEl = document.getElementById("netValue");
    if (netEl) netEl.innerHTML = "RX: …<br>TX: …";
    smoothUpdate(document.getElementById("tempValue"), "…", "°C");
    const uptimeEl = document.getElementById("uptimeBadge");
    if (uptimeEl) uptimeEl.textContent = "Uptime: …";
}

// -------------------------------------------------------------
// Fetch Earnings (Honeygain + Pawns + Today + Projected + Total)
// -------------------------------------------------------------
async function loadEarnings() {
    try {
        const res = await fetch(`${API}/earnings/run-now`, {
            method: "POST"
        });
        if (!res.ok) throw new Error("HTTP error");

        const data = await res.json();

        smoothUpdate(document.getElementById("honeygain-balance"), `$${data.honeygain.toFixed(2)}`);
        smoothUpdate(document.getElementById("pawns-balance"), `$${data.pawns.toFixed(2)}`);
        smoothUpdate(document.getElementById("today-earnings"), `$${data.daily_change.toFixed(2)}`);
        smoothUpdate(document.getElementById("projected-earnings"), `$${data.projected_30_day.toFixed(2)}`);

        const total = data.honeygain + data.pawns;
        smoothUpdate(document.getElementById("total-earnings"), `$${total.toFixed(2)}`);

    } catch (err) {
        console.error("Earnings load error:", err);
    }
}

// -------------------------------------------------------------
// Fetch System Stats (with retry)
// -------------------------------------------------------------
async function loadSystemStats() {
    try {
        const res = await fetch(`${API}/api/system`);
        if (!res.ok) throw new Error("HTTP error");

        const data = await res.json();
        if (!data.ok) throw new Error("Backend not ready");

        smoothUpdate(document.getElementById("cpuValue"), data.cpu.toFixed(1), "%");
        smoothUpdate(document.getElementById("ramValue"), data.ram, "%");
        smoothUpdate(document.getElementById("diskValue"), data.disk, "%");

        const rxKB = data.network.rx.toFixed(1);
        const txKB = data.network.tx.toFixed(1);
        const netEl = document.getElementById("netValue");
        if (netEl) {
            netEl.innerHTML = `RX: ${rxKB} KB/s<br>TX: ${txKB} KB/s`;
        }

        smoothUpdate(
            document.getElementById("tempValue"),
            data.temp ? data.temp.toFixed(1) : "--",
            "°C"
        );

        const hours = (data.uptime / 3600).toFixed(1);
        const uptimeEl = document.getElementById("uptimeBadge");
        if (uptimeEl) uptimeEl.textContent = `Uptime: ${hours} hrs`;

        setTimeout(loadSystemStats, 5000);

    } catch (err) {
        showLoading();
        setTimeout(loadSystemStats, 2000);
    }
}

// -------------------------------------------------------------
// Fetch Service Status
// -------------------------------------------------------------
async function loadServiceStatus() {
    try {
        const res = await fetch(`${API}/api/services`);
        if (!res.ok) throw new Error("HTTP error");

        const data = await res.json();
        const badge = document.getElementById("serviceBadge");
        if (badge) badge.textContent = `Reset Service: ${data.resetService}`;

    } catch (err) {
        console.error("Service status error:", err);
    }
}

// -------------------------------------------------------------
// Fetch Containers
// -------------------------------------------------------------
async function loadContainers() {
    if (logsOpen) return;

    try {
        const res = await fetch(`${API}/api/containers`);
        if (!res.ok) throw new Error("HTTP error");

        const containers = await res.json();

        const grid = document.getElementById("containerGrid");
        if (!grid) return;
        grid.innerHTML = "";

        containers.forEach(c => {
            const card = document.createElement("div");
            card.className = "container-card";

            card.innerHTML = `
                <h3>${c.Names[0].replace("/", "")}</h3>
                <div class="container-info">
                    <strong>Image:</strong> ${c.Image}<br>
                    <strong>ID:</strong> ${c.Id.substring(0, 12)}<br>
                    <strong>Status:</strong> ${c.State}
                </div>

                <div class="container-controls">
                    <button class="startBtn" data-id="${c.Id}">▶ Start</button>
                    <button class="stopBtn" data-id="${c.Id}">■ Stop</button>
                    <button class="restartBtn" data-id="${c.Id}">↻ Restart</button>
                    <button class="logsBtn" data-id="${c.Id}">📄 Logs</button>
                </div>
            `;

            grid.appendChild(card);
        });

        attachContainerEvents();

    } catch (err) {
        console.error("Container load error:", err);
    }
}

// -------------------------------------------------------------
// Container Control Events
// -------------------------------------------------------------
function attachContainerEvents() {
    document.querySelectorAll(".startBtn").forEach(btn => {
        btn.onclick = () => containerAction(btn.dataset.id, "start");
    });

    document.querySelectorAll(".stopBtn").forEach(btn => {
        btn.onclick = () => containerAction(btn.dataset.id, "stop");
    });

    document.querySelectorAll(".restartBtn").forEach(btn => {
        btn.onclick = () => containerAction(btn.dataset.id, "restart");
    });

    document.querySelectorAll(".logsBtn").forEach(btn => {
        btn.onclick = () => loadLogs(btn.dataset.id);
    });
}

// -------------------------------------------------------------
// Container Actions
// -------------------------------------------------------------
async function containerAction(id, action) {
    try {
        await fetch(`${API}/api/containers/${id}/${action}`, { method: "POST" });
        loadContainers();
    } catch (err) {
        console.error(`Container ${action} error:`, err);
    }
}

// -------------------------------------------------------------
// Load Logs
// -------------------------------------------------------------
async function loadLogs(id) {
    logsOpen = true;
    try {
        const res = await fetch(`${API}/api/containers/${id}/logs`);
        if (!res.ok) throw new Error("HTTP error");

        const data = await res.json();

        const modal = document.getElementById("logsModal");
        const content = document.getElementById("logsContent");

        if (modal && content) {
            content.textContent = data.logs.join("\n");
            modal.style.display = "block";
        }

    } catch (err) {
        console.error("Logs error:", err);
    }
}

// -------------------------------------------------------------
// Modal wiring
// -------------------------------------------------------------
function setupModal() {
    const modal = document.getElementById("logsModal");
    const closeBtn = document.getElementById("closeLogs");
    const refreshBtn = document.getElementById("refreshLogs");

    if (closeBtn && modal) {
        closeBtn.onclick = () => {
            logsOpen = false;
            modal.style.display = "none";
        };
    }

    window.addEventListener("click", (e) => {
        if (logsOpen && e.target === modal) {
            logsOpen = false;
            modal.style.display = "none";
        }
    });

    if (refreshBtn) {
        refreshBtn.onclick = () => {
            const openLogBtn = document.querySelector(".logsBtn[data-id]");
            if (openLogBtn) {
                loadLogs(openLogBtn.dataset.id);
            }
        };
    }
}

// -------------------------------------------------------------
// Projection Dropdown + Neon Bar
// -------------------------------------------------------------
async function updateProjection() {
    const mode = document.getElementById("projection-mode").value;

    try {
        const res = await fetch(`${API}/api/projection/${mode}`);
        const data = await res.json();

        document.getElementById("projection-display").textContent =
            `$${data.projection} / month (${mode})`;

    } catch (err) {
        console.error("Projection error:", err);
    }
}

document.getElementById("projection-mode").addEventListener("change", updateProjection);

// -------------------------------------------------------------
// Auto-refresh loops
// -------------------------------------------------------------
setInterval(loadServiceStatus, 5000);
setInterval(loadContainers, 5000);
setInterval(updateProjection, 10000);
setInterval(loadEarnings, 5000);

// Initial load
showLoading();
loadSystemStats();
loadServiceStatus();
loadContainers();
updateProjection();
setupModal();
