/* ---------------------------------------------------------
   EarnBox Cyberpunk SPA Dashboard
   Floating Glass Sidebar + Live Data
--------------------------------------------------------- */

let currentView = "dashboard";
let apiData = null;

/* ---------------------------------------------------------
   SIDEBAR + ORB TOGGLE
--------------------------------------------------------- */

const sidebar = document.getElementById("sidebar");
const sidebarOrb = document.getElementById("sidebarOrb");
const sidebarToggle = document.getElementById("sidebarToggle");

sidebarToggle.addEventListener("click", () => collapseSidebar());
sidebarOrb.addEventListener("click", () => expandSidebar());

function collapseSidebar() {
    sidebar.classList.add("collapsed");
    sidebarOrb.classList.add("visible");
}

function expandSidebar() {
    sidebar.classList.remove("collapsed");
    sidebarOrb.classList.remove("visible");
}

/* ---------------------------------------------------------
   SPA ROUTER
--------------------------------------------------------- */

const viewContainer = document.getElementById("view-container");
const navButtons = document.querySelectorAll(".nav-btn");

navButtons.forEach(btn => {
    btn.addEventListener("click", () => {
        navButtons.forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        currentView = btn.dataset.view;
        renderView();
    });
});

/* ---------------------------------------------------------
   FETCH LIVE DATA
--------------------------------------------------------- */

async function fetchData() {
    try {
        const response = await fetch("/local-api/api.json");
        apiData = await response.json();
        renderView();
    } catch (err) {
        console.error("API fetch failed:", err);
    }
}

setInterval(fetchData, 5000);
fetchData();

/* ---------------------------------------------------------
   VIEW RENDERING
--------------------------------------------------------- */

function renderView() {
    if (!apiData) return;

    switch (currentView) {
        case "dashboard":
            renderDashboard();
            break;
        case "containers":
            renderContainers();
            break;
        case "system":
            renderSystem();
            break;
        case "earnings":
            renderEarnings();
            break;
        case "logs":
            renderLogs();
            break;
    }
}

/* ---------------------------------------------------------
   DASHBOARD VIEW
--------------------------------------------------------- */

function renderDashboard() {
    viewContainer.innerHTML = `
        <div class="card">
            <div class="card-title">EarnApp Earnings</div>
            <div id="earningsValue">${apiData.earnapp.earnings} USD</div>
        </div>

        <div class="card">
            <div class="card-title">Container Status</div>
            <div>${Object.keys(apiData.containers).length} containers monitored</div>
        </div>

        <div class="card">
            <div class="card-title">System Health</div>
            <div>Pi Temp: ${apiData.pi.temp}</div>
            <div>HDD: ${apiData.hdd.health}</div>
            <div>Power: ${apiData.power.undervolt ? "⚠ Undervolt" : "Stable"}</div>
        </div>
    `;
}

/* ---------------------------------------------------------
   CONTAINERS VIEW
--------------------------------------------------------- */

function renderContainers() {
    let html = `<div class="card"><div class="card-title">Containers</div>`;

    for (const [name, c] of Object.entries(apiData.containers)) {
        html += `
            <div class="card" style="margin-top:15px;">
                <div class="card-title">${name}</div>
                <div>Status: ${c.status}</div>
                <div>CPU: ${c.cpu}</div>
                <div>RAM: ${c.ram}</div>
                <div>Uptime: ${c.uptime}</div>
            </div>
        `;
    }

    html += `</div>`;
    viewContainer.innerHTML = html;
}

/* ---------------------------------------------------------
   SYSTEM VIEW
--------------------------------------------------------- */

function renderSystem() {
    viewContainer.innerHTML = `
        <div class="card">
            <div class="card-title">Power</div>
            <div>Undervolt: ${apiData.power.undervolt}</div>
            <div>Throttled: ${apiData.power.throttled}</div>
            <div>Voltage: ${apiData.power.voltage}</div>
        </div>

        <div class="card">
            <div class="card-title">HDD</div>
            <div>Health: ${apiData.hdd.health}</div>
            <div>Temp: ${apiData.hdd.temp}</div>
            <div>Free Space: ${apiData.hdd.free}</div>
        </div>

        <div class="card">
            <div class="card-title">Pi</div>
            <div>Temp: ${apiData.pi.temp}</div>
            <div>Load: ${apiData.pi.load}</div>
            <div>Uptime: ${apiData.pi.uptime}</div>
        </div>
    `;
}

/* ---------------------------------------------------------
   EARNINGS VIEW
--------------------------------------------------------- */

function renderEarnings() {
    viewContainer.innerHTML = `
        <div class="card">
            <div class="card-title">EarnApp Earnings</div>
            <div>Total: ${apiData.earnapp.earnings} USD</div>
            <div>Status: ${apiData.earnapp.device_status}</div>
            <div>Last Check-in: ${apiData.earnapp.last_checkin}</div>
        </div>
    `;
}

/* ---------------------------------------------------------
   LOGS VIEW
--------------------------------------------------------- */

function renderLogs() {
    viewContainer.innerHTML = `
        <div class="card">
            <div class="card-title">Container Logs</div>
            <div class="log-box" id="logBox">Loading logs...</div>
        </div>
    `;

    fetchLogs();
}

async function fetchLogs() {
    try {
        const response = await fetch("/local-api/logs.txt");
        const text = await response.text();
        document.getElementById("logBox").textContent = text;
    } catch {
        document.getElementById("logBox").textContent = "Failed to load logs.";
    }
}
