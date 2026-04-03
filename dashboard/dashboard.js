/* ============================================================
   DASHBOARD.JS — Glass & Glow Edition
   Handles:
   - Page switching
   - Theme engine
   - Diagnostics ingestion
   - Auto-refresh
   - Animated service cards
   - Logs loading
   - Uptime counter
   ============================================================ */

/* -------------------------------
   PAGE SWITCHING
-------------------------------- */
const navButtons = document.querySelectorAll(".nav-btn");
const sections = document.querySelectorAll(".page-section");

navButtons.forEach(btn => {
    btn.addEventListener("click", () => {
        navButtons.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");

        const target = btn.dataset.target;

        sections.forEach(sec => {
            sec.classList.remove("active");
            if (sec.id === target) sec.classList.add("active");
        });
    });
});


/* -------------------------------
   THEME ENGINE
-------------------------------- */
const themeSwitch = document.getElementById("themeSwitch");

function applyTheme(dark) {
    document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
    localStorage.setItem("theme", dark ? "dark" : "light");
}

themeSwitch.addEventListener("change", () => {
    applyTheme(themeSwitch.checked);
});

// Load saved theme
const savedTheme = localStorage.getItem("theme");
if (savedTheme) {
    themeSwitch.checked = savedTheme === "dark";
    applyTheme(savedTheme === "dark");
}


/* -------------------------------
   DIAGNOSTICS FETCHER
-------------------------------- */
async function fetchDiagnostics() {
    try {
        const res = await fetch("/diagnostics.json?_=" + Date.now());
        return await res.json();
    } catch (err) {
        console.error("Diagnostics fetch failed:", err);
        return null;
    }
}


/* -------------------------------
   UPDATE OVERVIEW STATS
-------------------------------- */
function updateOverview(data) {
    if (!data) return;

    // Earnings
    const earnings = data.total_earnings || 0;
    document.getElementById("earnings-value").textContent = `$${earnings.toFixed(2)}`;

    // Active services
    const active = data.services ? Object.keys(data.services).length : 0;
    document.getElementById("services-value").textContent = active;

    // Uptime
    if (data.system && data.system.uptime) {
        document.getElementById("uptime-value").textContent = data.system.uptime;
    }
}


/* -------------------------------
   SERVICE CARD BUILDER
-------------------------------- */
function buildServiceCard(name, info) {
    const card = document.createElement("div");
    card.className = "glass-card service-card fade-in";

    const statusColor = info.online ? "var(--accent)" : "#ff4d4d";
    const statusText = info.online ? "Online" : "Offline";

    card.innerHTML = `
        <h3 class="service-title">${name}</h3>
        <div class="service-status" style="color:${statusColor}">
            ● ${statusText}
        </div>
        <div class="service-details">
            <p><strong>Earnings:</strong> $${info.earnings?.toFixed(2) || "0.00"}</p>
            <p><strong>Last Update:</strong> ${info.last_update || "N/A"}</p>
        </div>
    `;

    return card;
}


/* -------------------------------
   UPDATE SERVICE STATUS GRID
-------------------------------- */
function updateServiceGrid(data) {
    const container = document.getElementById("status-container");
    container.innerHTML = "";

    if (!data || !data.services) return;

    Object.entries(data.services).forEach(([name, info]) => {
        container.appendChild(buildServiceCard(name, info));
    });
}


/* -------------------------------
   SYSTEM INFO PANEL
-------------------------------- */
function updateSystemInfo(data) {
    const container = document.getElementById("system-info");
    container.innerHTML = "";

    if (!data || !data.system) return;

    Object.entries(data.system).forEach(([key, value]) => {
        const item = document.createElement("div");
        item.className = "glass-card info-item";
        item.innerHTML = `<strong>${key}:</strong> ${value}`;
        container.appendChild(item);
    });
}


/* -------------------------------
   NETWORK INFO PANEL
-------------------------------- */
function updateNetworkInfo(data) {
    const container = document.getElementById("network-info");
    container.innerHTML = "";

    if (!data || !data.network) return;

    Object.entries(data.network).forEach(([key, value]) => {
        const item = document.createElement("div");
        item.className = "glass-card info-item";
        item.innerHTML = `<strong>${key}:</strong> ${value}`;
        container.appendChild(item);
    });
}


/* -------------------------------
   LOGS LOADER
-------------------------------- */
async function loadLogs() {
    try {
        const res = await fetch("/logs.txt?_=" + Date.now());
        const text = await res.text();
        document.getElementById("logs-output").textContent = text;
    } catch {
        document.getElementById("logs-output").textContent = "Failed to load logs.";
    }
}


/* -------------------------------
   AUTO-REFRESH ENGINE
-------------------------------- */
async function refreshDashboard() {
    const data = await fetchDiagnostics();

    updateOverview(data);
    updateServiceGrid(data);
    updateSystemInfo(data);
    updateNetworkInfo(data);
    loadLogs();
}

// Refresh every 5 seconds
setInterval(refreshDashboard, 5000);

// Initial load
refreshDashboard();
