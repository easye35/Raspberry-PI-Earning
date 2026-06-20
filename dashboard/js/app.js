// -------------------------------------------------------------
// API base URL (backend proxy)
// -------------------------------------------------------------
const API = `${window.location.protocol}//${window.location.hostname}:3001`;

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
function safeAmount(value) {
    return typeof value === "number" && !isNaN(value) ? value : 0.0;
}

async function loadEarnings() {
    try {
        const res = await fetch(`${API}/earnings`);
        if (!res.ok) throw new Error("HTTP error");

        const data = await res.json();

        const honeygain = safeAmount(data.honeygain);
        const pawns = safeAmount(data.pawns);
        const dailyAverage = safeAmount(data.daily_average_30_day);
        const projected = safeAmount(data.projected_30_day);
        const total = safeAmount(data.total) || honeygain + pawns;

        smoothUpdate(document.getElementById("honeygain-balance"), `$${honeygain.toFixed(2)}`);
        smoothUpdate(document.getElementById("pawns-balance"), `$${pawns.toFixed(2)}`);
        smoothUpdate(document.getElementById("today-earnings"), `$${dailyAverage.toFixed(2)}`);
        smoothUpdate(document.getElementById("projected-earnings"), `$${projected.toFixed(2)}`);
        smoothUpdate(document.getElementById("total-earnings"), `$${total.toFixed(2)}`);

    } catch (err) {
        console.error("Earnings load error:", err);
    }
}

async function loadEarningsHistory() {
    try {
        const res = await fetch(`${API}/earnings/history?limit=14`);
        if (!res.ok) throw new Error("HTTP error");

        const data = await res.json();
        const history = Array.isArray(data.items) ? data.items : [];
        const container = document.getElementById("earningsHistory");
        const summary = document.getElementById("historySummary");
        const avgEl = document.getElementById("historyAvg");

        if (!container) return;
        container.innerHTML = "";

        if (!history.length) {
            summary.textContent = "No recorded history yet";
            avgEl.textContent = "";
            container.innerHTML = `<div class="empty-state">No history available</div>`;
            return;
        }

        const values = history
            .map(item => Number(item.daily_change) || 0)
            .reverse();

        const maxValue = Math.max(...values.map(Math.abs), 1);
        const average = values.reduce((sum, value) => sum + value, 0) / values.length;

        summary.textContent = `Last ${values.length} daily entries`;
        avgEl.textContent = `$${average.toFixed(2)} avg`;

        values.forEach((value, index) => {
            const bar = document.createElement("div");
            bar.className = "history-bar";
            bar.dataset.value = `$${value.toFixed(2)}`;

            const fill = document.createElement("div");
            fill.className = "history-bar-fill";
            fill.style.height = `${Math.max((value / maxValue) * 100, 4)}%`;
            if (value < 0) {
                fill.style.background = "linear-gradient(180deg, rgba(255, 96, 128, 0.95), rgba(255, 80, 170, 0.9))";
            }

            bar.appendChild(fill);
            container.appendChild(bar);
        });

    } catch (err) {
        console.error("Earnings history load error:", err);
    }
}

// -------------------------------------------------------------
// Metric history persistence
const HISTORY_KEY = "earnboxMetricHistory";
const metricHistory = {
    cpu: [],
    ram: [],
    disk: [],
    netRx: [],
    netTx: [],
    temp: []
};
const metricHistoryConfig = {
    cpu: 24,
    ram: 24,
    disk: 24,
    temp: 24,
    netRx: 720,
    netTx: 720
};

function loadMetricHistory() {
    try {
        const stored = JSON.parse(localStorage.getItem(HISTORY_KEY) || "{}");
        Object.keys(metricHistory).forEach((key) => {
            if (Array.isArray(stored[key])) {
                metricHistory[key] = stored[key].slice(-metricHistoryConfig[key]);
            }
        });
    } catch (err) {
        console.warn("Could not parse metric history:", err);
    }
}

function saveMetricHistory() {
    localStorage.setItem(HISTORY_KEY, JSON.stringify(metricHistory));
}

function addMetricHistoryPoint(key, value) {
    const hour = Math.floor(Date.now() / 3600000);
    const history = metricHistory[key];
    const maxLength = metricHistoryConfig[key] || 24;
    if (!history.length || history[history.length - 1].hour !== hour) {
        history.push({ hour, value });
        if (history.length > maxLength) history.shift();
    } else {
        history[history.length - 1].value = (history[history.length - 1].value + value) / 2;
    }
    saveMetricHistory();
}

function renderMetricHistory(key, elementId, scaleMax, dataType = "cpu") {
    const container = document.getElementById(elementId);
    if (!container) return;
    container.innerHTML = "";

    const history = metricHistory[key] || [];
    const display = history.slice(-24);
    if (!display.length) {
        container.innerHTML = `<div class="history-empty">No history yet</div>`;
        return;
    }

    display.forEach((entry) => {
        const bar = document.createElement("div");
        const value = Number(entry.value) || 0;
        const height = Math.max(Math.min((value / scaleMax) * 100, 100), 6);
        bar.className = "metric-history-segment";
        bar.dataset.type = dataType;
        bar.dataset.value = dataType === "temp" ? `${value.toFixed(1)}°C` : `${value.toFixed(1)}${dataType === "netRx" || dataType === "netTx" ? " KB/s" : "%"}`;
        bar.style.height = `${height}%`;
        container.appendChild(bar);
    });
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

        const cpuBar = document.getElementById("cpuBar");
        const ramBar = document.getElementById("ramBar");
        const diskBar = document.getElementById("diskBar");
        if (cpuBar) cpuBar.style.width = `${Math.min(Math.max(data.cpu, 0), 100)}%`;
        if (ramBar) ramBar.style.width = `${Math.min(Math.max(data.ram, 0), 100)}%`;
        if (diskBar) diskBar.style.width = `${Math.min(Math.max(data.disk, 0), 100)}%`;

        const cpuLabel = document.getElementById("cpuLabel");
        const ramLabel = document.getElementById("ramLabel");
        const diskLabel = document.getElementById("diskLabel");
        if (cpuLabel) cpuLabel.textContent = `${data.cpu.toFixed(1)}%`;
        if (ramLabel) ramLabel.textContent = `${data.ram.toFixed(1)}%`;
        if (diskLabel) diskLabel.textContent = `${data.disk.toFixed(1)}%`;

        const rxKB = data.network.rx.toFixed(1);
        const txKB = data.network.tx.toFixed(1);
        const netEl = document.getElementById("netValue");
        if (netEl) {
            netEl.innerHTML = `RX: ${rxKB} KB/s<br>TX: ${txKB} KB/s`;
        }

        const netRxBar = document.getElementById("netRxBar");
        const netTxBar = document.getElementById("netTxBar");
        const netRxLabel = document.getElementById("netRxLabel");
        const netTxLabel = document.getElementById("netTxLabel");
        const rxPct = Math.min(Math.max((data.network.rx / 50) * 100, 0), 100);
        const txPct = Math.min(Math.max((data.network.tx / 50) * 100, 0), 100);
        if (netRxBar) netRxBar.style.width = `${rxPct}%`;
        if (netTxBar) netTxBar.style.width = `${txPct}%`;
        if (netRxLabel) netRxLabel.textContent = `RX ${rxKB}`;
        if (netTxLabel) netTxLabel.textContent = `TX ${txKB}`;

        const network30DayValue = calculateNetwork30DayUsage();
        const network30DayEl = document.getElementById("network30DayValue");
        if (network30DayEl) network30DayEl.textContent = `30d usage: ${network30DayValue}`;

        smoothUpdate(
            document.getElementById("tempValue"),
            data.temp ? data.temp.toFixed(1) : "--",
            "°C"
        );
        const tempBar = document.getElementById("tempBar");
        const tempLabel = document.getElementById("tempLabel");
        const tempPct = data.temp ? Math.min(Math.max((data.temp / 80) * 100, 0), 100) : 0;
        if (tempBar) tempBar.style.width = `${tempPct}%`;
        if (tempLabel) tempLabel.textContent = data.temp ? `${data.temp.toFixed(1)}°C` : "--";

        const hours = (data.uptime / 3600).toFixed(1);
        const uptimeEl = document.getElementById("uptimeBadge");
        if (uptimeEl) uptimeEl.textContent = `Uptime: ${hours} hrs`;

        addMetricHistoryPoint("cpu", data.cpu);
        addMetricHistoryPoint("ram", data.ram);
        addMetricHistoryPoint("disk", data.disk);
        addMetricHistoryPoint("temp", data.temp || 0);
        addMetricHistoryPoint("netRx", data.network.rx);
        addMetricHistoryPoint("netTx", data.network.tx);

        renderMetricHistory("cpu", "cpuHistory", 100, "cpu");
        renderMetricHistory("ram", "ramHistory", 100, "ram");
        renderMetricHistory("disk", "diskHistory", 100, "disk");
        renderMetricHistory("temp", "tempHistory", 80, "temp");
        renderMetricHistory("netRx", "netRxHistory", 50, "netRx");
        renderMetricHistory("netTx", "netTxHistory", 50, "netTx");

        setTimeout(loadSystemStats, 5000);

    } catch (err) {
        showLoading();
        setTimeout(loadSystemStats, 2000);
    }
}

function calculateNetwork30DayUsage() {
    const toGB = (kb) => kb / 1024 / 1024;
    const rxHistory = metricHistory.netRx || [];
    const txHistory = metricHistory.netTx || [];

    const rxTotalKB = rxHistory.reduce((sum, point) => sum + (Number(point.value) || 0) * 3600, 0);
    const txTotalKB = txHistory.reduce((sum, point) => sum + (Number(point.value) || 0) * 3600, 0);

    const totalGB = toGB(rxTotalKB + txTotalKB);
    return `${totalGB.toFixed(2)} GB`;
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

        const versionEl = document.getElementById("versionBadge");
        if (versionEl) versionEl.textContent = data.version || "Unknown";

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
// Diagnostics button
// -------------------------------------------------------------
async function runDiagnostics() {
    const diagButton = document.getElementById("diagnosticsBtn");
    if (diagButton) {
        diagButton.textContent = "Checking...";
        diagButton.disabled = true;
    }

    await Promise.allSettled([
        loadSystemStats(),
        loadServiceStatus(),
        loadContainers(),
        loadEarnings(),
        loadEarningsHistory()
    ]);

    if (diagButton) {
        diagButton.textContent = "Diagnostics";
        diagButton.disabled = false;
    }
}

// -------------------------------------------------------------
// Auto-refresh loops
// -------------------------------------------------------------
setInterval(loadServiceStatus, 5000);
setInterval(loadContainers, 5000);
setInterval(loadEarnings, 120000);

// Initial load
loadMetricHistory();
showLoading();
loadSystemStats();
loadServiceStatus();
loadContainers();
loadEarnings();
loadEarningsHistory();
setupModal();

const diagnosticsBtn = document.getElementById("diagnosticsBtn");
if (diagnosticsBtn) {
    diagnosticsBtn.onclick = runDiagnostics;
}

const refreshAllBtn = document.getElementById("refreshAllBtn");
if (refreshAllBtn) {
    refreshAllBtn.onclick = () => {
        loadSystemStats();
        loadServiceStatus();
        loadContainers();
        loadEarnings();
        loadEarningsHistory();
    };
}

const refreshHistoryBtn = document.getElementById("refreshHistoryBtn");
if (refreshHistoryBtn) {
    refreshHistoryBtn.onclick = loadEarningsHistory;
}
