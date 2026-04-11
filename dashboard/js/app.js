// ------------------------------------------------------------
// EarnBox Dashboard SPA
// ------------------------------------------------------------

const state = {
    currentView: "dashboard",
    adminUnlocked: false,
    logoClickCount: 0,
    logoClickTimeout: null,
    containers: []
};

const views = {};

// ------------------------------------------------------------
// Utility: Switch View
// ------------------------------------------------------------
function setView(view) {
    state.currentView = view;
    render();
}

// ------------------------------------------------------------
// Sidebar + Orb Toggle
// ------------------------------------------------------------
function toggleSidebar() {
    document.body.classList.toggle("sidebar-collapsed");
}

function initSidebar() {
    const orb = document.getElementById("orb-toggle");
    if (orb) {
        orb.onclick = toggleSidebar;
    }

    document.querySelectorAll("[data-view]").forEach(el => {
        el.onclick = () => {
            const view = el.getAttribute("data-view");
            setView(view);
        };
    });
}

// ------------------------------------------------------------
// Logo Secret Admin Unlock (5 clicks)
// ------------------------------------------------------------
function initLogoUnlock() {
    const logo = document.getElementById("brand-logo");
    if (!logo) return;

    logo.addEventListener("click", () => {
        state.logoClickCount++;

        if (state.logoClickTimeout) {
            clearTimeout(state.logoClickTimeout);
        }

        state.logoClickTimeout = setTimeout(() => {
            state.logoClickCount = 0;
        }, 2000);

        if (state.logoClickCount >= 5) {
            state.adminUnlocked = true;
            state.logoClickCount = 0;
            alert("Admin Panel unlocked");
            setView("admin");
        }
    });
}

// ------------------------------------------------------------
// API Helpers
// ------------------------------------------------------------
async function fetchContainers() {
    try {
        const res = await fetch("/api/containers");
        state.containers = await res.json();
    } catch (e) {
        console.error("Failed to fetch containers", e);
        state.containers = [];
    }
}

async function restartContainers() {
    await fetch("/api/admin/reset", { method: "POST" });
    alert("Containers restarting");
}

async function enableDailyReset() {
    await fetch("/api/admin/enable-daily-reset", { method: "POST" });
    alert("Daily reset enabled");
}

// ------------------------------------------------------------
// Admin: .env Management
// ------------------------------------------------------------
async function loadEnv() {
    try {
        const env = await fetch("/api/admin/env").then(r => r.json());

        const map = {
            PAWNS_EMAIL: "pawnsEmail",
            PAWNS_PASSWORD: "pawnsPass",
            PAWNS_DEVICE: "pawnsDevice",
            HONEYGAIN_EMAIL: "hgEmail",
            HONEYGAIN_PASSWORD: "hgPass",
            EARNAPP_EMAIL: "eaEmail",
            EARNAPP_PASSWORD: "eaPass"
        };

        Object.entries(map).forEach(([envKey, inputId]) => {
            const el = document.getElementById(inputId);
            if (el && env[envKey] !== undefined) {
                el.value = env[envKey];
            }
        });
    } catch (e) {
        console.error("Failed to load .env", e);
    }
}

async function saveEnv() {
    const data = {
        PAWNS_EMAIL: document.getElementById("pawnsEmail")?.value || "",
        PAWNS_PASSWORD: document.getElementById("pawnsPass")?.value || "",
        PAWNS_DEVICE: document.getElementById("pawnsDevice")?.value || "",
        HONEYGAIN_EMAIL: document.getElementById("hgEmail")?.value || "",
        HONEYGAIN_PASSWORD: document.getElementById("hgPass")?.value || "",
        EARNAPP_EMAIL: document.getElementById("eaEmail")?.value || "",
        EARNAPP_PASSWORD: document.getElementById("eaPass")?.value || ""
    };

    await fetch("/api/admin/env", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data)
    });

    alert("Credentials saved to .env");
}

async function applyEnv() {
    await fetch("/api/admin/apply-env", { method: "POST" });
    alert("Containers restarted with new credentials");
}

// ------------------------------------------------------------
// Views
// ------------------------------------------------------------

// Dashboard View
views["dashboard"] = {
    name: "Dashboard",
    render: () => {
        const running = state.containers.filter(c => c.status === "running").length;
        const total = state.containers.length;

        return `
            <div class="view dashboard-view">
                <h1>EarnBox Overview</h1>
                <div class="cards-row">
                    <div class="glass-card">
                        <h2>Containers</h2>
                        <p>${running} / ${total} running</p>
                    </div>
                    <div class="glass-card">
                        <h2>Status</h2>
                        <p>${running === total && total > 0 ? "All systems nominal" : "Attention required"}</p>
                    </div>
                </div>
            </div>
        `;
    }
};

// Containers View
views["containers"] = {
    name: "Containers",
    render: () => {
        const rows = state.containers.map(c => `
            <tr>
                <td>${c.name}</td>
                <td>${c.type}</td>
                <td class="${c.status === "running" ? "status-ok" : "status-bad"}">${c.status}</td>
                <td>${c.port || "-"}</td>
                <td>
                    ${c.ui && c.login_url ? `<a href="${c.login_url}" target="_blank">Open</a>` : "-"}
                </td>
            </tr>
        `).join("");

        return `
            <div class="view containers-view">
                <h1>Containers</h1>
                <div class="table-wrapper glass-card">
                    <table>
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Type</th>
                                <th>Status</th>
                                <th>Port</th>
                                <th>UI</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${rows || `<tr><td colspan="5">No containers found</td></tr>`}
                        </tbody>
                    </table>
                </div>
            </div>
        `;
    }
};

// System View (stub)
views["system"] = {
    name: "System",
    render: () => `
        <div class="view system-view">
            <h1>System</h1>
            <p>System metrics and hardware info can go here.</p>
        </div>
    `
};

// Logs View (stub)
views["logs"] = {
    name: "Logs",
    render: () => `
        <div class="view logs-view">
            <h1>Logs</h1>
            <p>Log streaming or recent events can go here.</p>
        </div>
    `
};

// Admin View (hidden, unlocked by logo clicks)
views["admin"] = {
    name: "Admin Panel",
    render: () => `
        <div class="view admin-view">
            <h1>Admin Panel</h1>

            <div class="admin-grid">
                <div class="admin-card glass-card">
                    <h3>Restart All Containers</h3>
                    <p>Force restart all running containers.</p>
                    <button onclick="restartContainers()">Restart</button>
                </div>

                <div class="admin-card glass-card">
                    <h3>Enable Daily Reset</h3>
                    <p>Run a daily container restart via systemd timer.</p>
                    <button onclick="enableDailyReset()">Enable</button>
                </div>

                <div class="admin-card glass-card">
                    <h3>Earning App Credentials</h3>

                    <label>Pawns Email</label>
                    <input id="pawnsEmail" class="admin-input" placeholder="Pawns Email" />

                    <label>Pawns Password</label>
                    <input id="pawnsPass" class="admin-input" placeholder="Pawns Password" type="password" />

                    <label>Pawns Device</label>
                    <input id="pawnsDevice" class="admin-input" placeholder="Pawns Device" />

                    <label>Honeygain Email</label>
                    <input id="hgEmail" class="admin-input" placeholder="Honeygain Email" />

                    <label>Honeygain Password</label>
                    <input id="hgPass" class="admin-input" placeholder="Honeygain Password" type="password" />

                    <label>EarnApp Email</label>
                    <input id="eaEmail" class="admin-input" placeholder="EarnApp Email" />

                    <label>EarnApp Password</label>
                    <input id="eaPass" class="admin-input" placeholder="EarnApp Password" type="password" />

                    <div class="admin-actions">
                        <button onclick="saveEnv()">Save</button>
                        <button onclick="applyEnv()">Apply & Restart</button>
                    </div>
                </div>
            </div>
        </div>
    `
};

// ------------------------------------------------------------
// Render Function
// ------------------------------------------------------------
function render() {
    const root = document.getElementById("app-root");
    if (!root) return;

    const view = views[state.currentView] || views["dashboard"];

    root.innerHTML = `
        <div class="layout">
            <aside class="sidebar">
                <div class="brand" id="brand-logo">
                    <span class="brand-mark">⧉</span>
                    <span class="brand-text">EarnBox</span>
                </div>
                <nav class="nav">
                    <button data-view="dashboard" class="${state.currentView === "dashboard" ? "active" : ""}">Dashboard</button>
                    <button data-view="containers" class="${state.currentView === "containers" ? "active" : ""}">Containers</button>
                    <button data-view="system" class="${state.currentView === "system" ? "active" : ""}">System</button>
                    <button data-view="logs" class="${state.currentView === "logs" ? "active" : ""}">Logs</button>
                    ${state.adminUnlocked ? `<button data-view="admin" class="${state.currentView === "admin" ? "active" : ""}">Admin</button>` : ""}
                </nav>
                <div class="orb-toggle" id="orb-toggle"></div>
            </aside>
            <main class="main">
                ${view.render()}
            </main>
        </div>
    `;

    initSidebar();
    initLogoUnlock();

    // If we just rendered admin, load .env values
    if (state.currentView === "admin") {
        setTimeout(loadEnv, 200);
    }
}

// ------------------------------------------------------------
// Initial Load
// ------------------------------------------------------------
async function init() {
    await fetchContainers();
    render();
}

window.addEventListener("DOMContentLoaded", init);
