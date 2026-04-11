// ------------------------------------------------------------
// EarnBox Dashboard - Modular Router + Plug‑in Architecture
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
}

// -------------------------------
// Dashboard View
// -------------------------------
const DashboardView = {
    name: "dashboard",
    render: async () => {
        const div = document.createElement("div");
        div.className = "dashboard-view";

        div.innerHTML = `
            <h1 class="view-title">Dashboard</h1>
            <p class="view-subtitle">Welcome to your EarnBox control center.</p>
        `;

        return div;
    }
};

// -------------------------------
// Containers Plug‑in View
// Auto‑discovers running containers
// -------------------------------
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
                card.className = "container-card";

                card.innerHTML = `
                    <div class="card-header">
                        <span class="container-name">${c.name}</span>
                        <span class="status-dot ${c.status}"></span>
                    </div>

                    <div class="card-body">
                        <div><strong>IP:</strong> ${c.ip}</div>
                        <div><strong>Port:</strong> ${c.port}</div>
                        <div><strong>Last Seen:</strong> ${c.last_seen}</div>
                    </div>

                    <button class="login-btn"
                        onclick="window.open('http://${c.ip}:${c.port}', '_blank')">
                        Login
                    </button>
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

// -------------------------------
// System View
// -------------------------------
const SystemView = {
    name: "system",
    render: async () => {
        const div = document.createElement("div");
        div.className = "system-view";

        div.innerHTML = `
            <h1 class="view-title">System</h1>
            <p class="view-subtitle">System information and diagnostics.</p>
        `;

        return div;
    }
};

// -------------------------------
// Logs View
// -------------------------------
const LogsView = {
    name: "logs",
    render: async () => {
        const div = document.createElement("div");
        div.className = "logs-view";

        div.innerHTML = `
            <h1 class="view-title">Logs</h1>
            <p class="view-subtitle">Container and system logs.</p>
        `;

        return div;
    }
};

// -------------------------------
// View Registry
// -------------------------------
const views = {
    dashboard: DashboardView,
    containers: ContainersView,
    system: SystemView,
    logs: LogsView
};

// -------------------------------
// Navigation Buttons
// -------------------------------
document.querySelectorAll(".nav-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        const view = btn.getAttribute("data-view");
        loadView(view);
    });
});

// -------------------------------
// Load Default View
// -------------------------------
loadView("dashboard");
