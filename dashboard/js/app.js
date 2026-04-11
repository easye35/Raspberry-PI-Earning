// ------------------------------------------------------------
// EarnBox Dashboard v2 — Full SPA Router + Views
// ------------------------------------------------------------

// -------------------------------
// Sidebar + Orb Toggle Logic
// -------------------------------
const sidebar = document.getElementById("sidebar");
const sidebarToggle = document.getElementById("sidebarToggle");
const sidebarOrb = document.getElementById("sidebarOrb");

sidebarToggle.addEventListener("click", () => {
    sidebar.classList.toggle("collapsed");
    sidebarOrb.classList.toggle("visible");
});

sidebarOrb.addEventListener("click", () => {
    sidebar.classList.toggle("collapsed");
    sidebarOrb.classList.toggle("visible");
});

// -------------------------------
// View Injection System
// -------------------------------
const viewContainer = document.getElementById("view-container");

async function loadView(viewName) {
    const view = views[viewName];

    if (!view) {
        viewContainer.innerHTML = `<div class="error">Unknown view: ${viewName}</div>`;
        return;
    }

    const content = await view.render();
    viewContainer.innerHTML = "";
    viewContainer.appendChild(content);

    // Highlight active nav button
    document.querySelectorAll(".nav-btn").forEach(btn => {
        btn.classList.toggle("active", btn.getAttribute("data-view") === viewName);
    });
}

// ------------------------------------------------------------
// DASHBOARD VIEW (Customer-facing)
// ------------------------------------------------------------
const DashboardView = {
    name: "dashboard",
    render: async () => {
        const div = document.createElement("div");
        div.className = "dashboard-view";

        div.innerHTML = `
            <h1 class="view-title">EarnBox Dashboard</h1>
            <p class="view-subtitle">Manage your earning apps and payout accounts</p>

            <div class="apps-grid">

                <div class="app-card">
                    <div class="app-icon">♟️</div>
                    <div class="app-name">Pawns.app</div>
                    <button class="app-btn" onclick="window.open('https://pawns.app/login', '_blank')">
                        Open Pawns Website
                    </button>
                </div>

                <div class="app-card">
                    <div class="app-icon">🍯</div>
                    <div class="app-name">Honeygain</div>
                    <button class="app-btn" onclick="window.open('https://dashboard.honeygain.com', '_blank')">
                        Open Honeygain Website
                    </button>
                </div>

                <div class="app-card">
                    <div class="app-icon">💸</div>
                    <div class="app-name">EarnApp</div>
                    <button class="app-btn" onclick="window.open('https://earnapp.com/dashboard', '_blank')">
                        Open EarnApp Website
                    </button>
                </div>

                <div class="app-card">
                    <div class="app-icon">🛠️</div>
                    <div class="app-name">Portainer</div>
                    <button class="app-btn" onclick="window.open('http://' + location.hostname + ':9000', '_blank')">
                        Open Portainer
                    </button>
                </div>

                <div class="app-card">
                    <div class="app-icon">📊</div>
                    <div class="app-name">Netdata</div>
                    <button class="app-btn" onclick="window.open('http://' + location.hostname + ':19999', '_blank')">
                        Open Netdata
                    </button>
                </div>

            </div>

            <div id="admin-unlock" class="admin-hidden">v2.0</div>
        `;

        return div;
    }
};

// ------------------------------------------------------------
// CONTAINERS VIEW (Auto-discovery)
// ------------------------------------------------------------
const ContainersView = {
    name: "containers",
    render: async () => {
        const container = document.createElement("div");
        container.className = "containers-view";

        container.innerHTML = `
            <h1 class="view-title">Containers</h1>
            <p class="view-subtitle">Auto‑discovered running containers</p>

            <div id="containersGrid" class="containers-grid">
                <div class="loading">Scanning Docker...</div>
            </div>
        `;

        const grid = container.querySelector("#containersGrid");

        try {
            const res = await fetch("/api/containers");
            const containers = await res.json();

            grid.innerHTML = "";

            if (!containers.length) {
                grid.innerHTML = `<div class="empty">No containers detected.</div>`;
                return container;
            }

            containers.forEach(c => {
                const card = document.createElement("div");
                card.className = `container-card type-${c.type}`;

                const icon = {
                    pawns: "♟️",
                    honeygain: "🍯",
                    portainer: "🛠️",
                    netdata: "📊",
                    dashboard: "🖥️",
                    generic: "📦"
                }[c.type] || "📦";

                const statusClass = c.status === "running" ? "running" : "stopped";

                card.innerHTML = `
                    <div class="card-header">
                        <span class="container-icon">${icon}</span>
                        <span class="container-name">${c.name}</span>
                        <span class="status-dot ${statusClass}"></span>
                    </div>

                    <div class="card-body">
                        <div><strong>Type:</strong> ${c.type}</div>
                        <div><strong>IP:</strong> ${c.ip}</div>
                        <div><strong>Port:</strong> ${c.port || "—"}</div>
                        <div><strong>Last Seen:</strong> ${c.last_seen}</div>
                    </div>

                    ${
                        c.ui && c.login_url
                        ? `<button class="login-btn" onclick="window.open('${c.login_url}', '_blank')">Open UI</button>`
                        : `<button class="login-btn disabled" disabled>No UI</button>`
                    }
                `;

                grid.appendChild(card);
            });

        } catch (err) {
            console.error(err);
            grid.innerHTML = `<div class="error">Failed to load containers.</div>`;
        }

        return container;
    }
};

// ------------------------------------------------------------
// ADMIN PANEL (Hidden)
// ------------------------------------------------------------
const AdminView = {
    name: "admin",
    render: async () => {
        const div = document.createElement("div");
        div.className = "admin-view";

        div.innerHTML = `
            <h1 class="view-title">Admin Panel</h1>
            <p class="view-subtitle">Advanced controls for EarnBox</p>

            <div class="admin-grid">

                <div class="admin-card">
                    <h3>Portainer</h3>
                    <button onclick="window.open('http://' + location.hostname + ':9000', '_blank')">
                        Open Portainer
                    </button>
                </div>

                <div class="admin-card">
                    <h3>Netdata</h3>
                    <button onclick="window.open('http://' + location.hostname + ':19999', '_blank')">
                        Open Netdata
                    </button>
                </div>

                <div class="admin-card">
                    <h3>Restart All Containers</h3>
                    <button onclick="fetch('/api/admin/reset', { method: 'POST' }).then(()=>alert('Restart requested'))">
                        Restart Containers
                    </button>
                </div>

                <div class="admin-card">
                    <h3>Enable Daily Auto‑Reset</h3>
                    <button onclick="fetch('/api/admin/enable-daily-reset', { method: 'POST' }).then(()=>alert('Daily reset enabled'))">
                        Enable Daily Reset
                    </button>
                </div>

                <div class="admin-card">
                    <h3>Change Dashboard Password</h3>
                    <p>(Coming soon)</p>
                </div>

            </div>
        `;

        return div;
    }
};

// ------------------------------------------------------------
// SYSTEM + LOGS (Stubs)
// ------------------------------------------------------------
const SystemView = {
    name: "system",
    render: async () => {
        const div = document.createElement("div");
        div.innerHTML = `
            <h1 class="view-title">System</h1>
            <p class="view-subtitle">System information and diagnostics.</p>
        `;
        return div;
    }
};

const LogsView = {
    name: "logs",
    render: async () => {
        const div = document.createElement("div");
        div.innerHTML = `
            <h1 class="view-title">Logs</h1>
            <p class="view-subtitle">Container and system logs.</p>
        `;
        return div;
    }
};

// ------------------------------------------------------------
// View Registry
// ------------------------------------------------------------
const views = {
    dashboard: DashboardView,
    containers: ContainersView,
    system: SystemView,
    logs: LogsView,
    admin: AdminView
};

// ------------------------------------------------------------
// Navigation Buttons
// ------------------------------------------------------------
document.querySelectorAll(".nav-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        const view = btn.getAttribute("data-view");
        loadView(view);
    });
});

// ------------------------------------------------------------
// Hidden Admin Unlock (click v2.0 5×)
// ------------------------------------------------------------
let adminClicks = 0;

document.addEventListener("click", (e) => {
    if (e.target.id === "admin-unlock") {
        adminClicks++;
        if (adminClicks >= 5) {
            loadView("admin");
            adminClicks = 0;
        }
    }
});

// ------------------------------------------------------------
// Load Default View
// ------------------------------------------------------------
loadView("dashboard");
