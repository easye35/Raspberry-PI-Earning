/* ---------------------------------------------------------------------------
   EarnBox Backend API (Corrected + DB Auto‑Init)
--------------------------------------------------------------------------- */

const express = require("express");
const fetch = require("node-fetch");
const cors = require("cors");
const { exec } = require("child_process");
const Docker = require("dockerode");
const fs = require("fs");

const docker = new Docker({ socketPath: "/var/run/docker.sock" });
const app = express();

app.use(cors());
app.use(express.json());

/* ---------------------------------------------------------------------------
   Earnings API (Honeygain + Pawns + DB)
--------------------------------------------------------------------------- */
app.get("/earnings", (req, res) => {
    try {
        // Load Honeygain + Pawns JSON from /data
        let honeygain = 0;
        let pawns = 0;

        try {
            const raw = fs.readFileSync("/data/latest_earnings.json", "utf8");
            const json = JSON.parse(raw);

            honeygain = json.honeygain || 0;
            pawns = json.pawns || 0;

        } catch (err) {
            console.log("No earnings JSON yet.");
        }

        // Load DB latest row
        const latest = db.prepare(
            "SELECT total, daily_change FROM earnings ORDER BY id DESC LIMIT 1"
        ).get();

        const daily = latest?.daily_change || 0;
        const total = latest?.total || (honeygain + pawns);

        // 30‑day projection (simple)
        const projected_30_day = daily * 30;

        res.json({
            honeygain,
            pawns,
            daily_change: daily,
            projected_30_day,
            total
        });

    } catch (err) {
        console.error("Earnings API error:", err);

        res.json({
            honeygain: 0,
            pawns: 0,
            daily_change: 0,
            projected_30_day: 0,
            total: 0
        });
    }
});
/*---------------------------------------------------------------------
 Utility: Fetch with Retry
--------------------------------------------------------------------------- */
async function fetchWithRetry(url, retries = 3, delay = 500) {
    for (let i = 0; i < retries; i++) {
        try {
            const res = await fetch(url);
            if (res.ok) return await res.json();
        } catch (err) {}
        await new Promise(r => setTimeout(r, delay));
    }
    return null;
}

/* ---------------------------------------------------------------------------
   Database Initialization (FIXED)
--------------------------------------------------------------------------- */
const Database = require("better-sqlite3");

// Ensure /data exists
fs.mkdirSync("/data", { recursive: true });

// Open DB
const db = new Database("/data/earnings.db");

// Ensure table exists
db.prepare(`
    CREATE TABLE IF NOT EXISTS earnings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        total REAL,
        daily_change REAL
    )
`).run();

/* ---------------------------------------------------------------------------
   Earnings Projection API
--------------------------------------------------------------------------- */
app.get("/api/projection/:mode", (req, res) => {
    const mode = req.params.mode;

    const rows = db.prepare(
        "SELECT daily_change FROM earnings ORDER BY id DESC LIMIT 30"
    ).all();

    const values = rows
        .map(r => r.daily_change)
        .filter(v => v !== null && !isNaN(v));

    if (values.length === 0) {
        return res.json({ projection: 0 });
    }

    let avg = 0;

    if (mode === "7day") {
        avg = values.slice(0, 7).reduce((a, b) => a + b, 0) / Math.min(7, values.length);
    } else if (mode === "30day") {
        avg = values.reduce((a, b) => a + b, 0) / values.length;
    } else if (mode === "weighted") {
        const a3 = values.slice(0, 3).reduce((a, b) => a + b, 0) / Math.min(3, values.length);
        const a7 = values.slice(0, 7).reduce((a, b) => a + b, 0) / Math.min(7, values.length);
        const a30 = values.reduce((a, b) => a + b, 0) / values.length;
        avg = a3 * 0.5 + a7 * 0.3 + a30 * 0.2;
    } else if (mode === "trend") {
        const x = values.map((_, i) => i);
        const y = values;

        const n = y.length;
        const sumX = x.reduce((a, b) => a + b, 0);
        const sumY = y.reduce((a, b) => a + b, 0);
        const sumXY = x.reduce((a, b, i) => a + b * y[i], 0);
        const sumX2 = x.reduce((a, b) => a + b * b, 0);

        const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
        avg = slope;
    } else {
        avg = values.reduce((a, b) => a + b, 0) / values.length;
    }

    const projection = avg * 30;
    res.json({ projection: Number(projection.toFixed(2)) });
});

/* ---------------------------------------------------------------------------
   System Stats (Netdata)
--------------------------------------------------------------------------- */
const NETDATA = "http://netdata:19999";

app.get("/api/system", async (req, res) => {
    try {
        // CPU
        const cpuChart = await fetchWithRetry(
            `${NETDATA}/api/v1/data?chart=system.cpu&after=-1&points=1&format=json`
        );
        if (!cpuChart) return res.json({ ok: false });

        const cpuRow = cpuChart?.data?.[0] || [];
        const user = cpuRow[6] || 0;
        const system = cpuRow[7] || 0;
        const nice = cpuRow[8] || 0;
        const iowait = cpuRow[9] || 0;
        const cpuTotal = user + system + nice + iowait;

        // RAM
        const ramChart = await fetchWithRetry(
            `${NETDATA}/api/v1/data?chart=system.ram&after=-1&points=1&format=json`
        );
        const ramRow = ramChart?.data?.[[0]] || [];
        const ramFree = ramRow[1] || 0;
        const ramUsed = ramRow[2] || 0;
        const ramPercent = Math.round((ramUsed / (ramUsed + ramFree)) * 100);

        // Disk
        const charts = await fetchWithRetry(`${NETDATA}/api/v1/charts`);
        let diskPercent = 0;

        const diskChartName = Object.keys(charts).find(k =>
            k.startsWith("disk_space.") && !k.includes("docker")
        );

        if (diskChartName) {
            const diskChart = await fetchWithRetry(
                `${NETDATA}/api/v1/data?chart=${diskChartName}&after=-1&points=1&format=json`
            );

            const diskRow = diskChart?.data?.[0] || [];
            const diskUsed = diskRow[1] || 0;
            const diskFree = diskRow[2] || 1;
            diskPercent = Math.round((diskUsed / (diskUsed + diskFree)) * 100);
        }

        // Network
        const iface = Object.keys(charts).find(k =>
            k.startsWith("net.") && !k.includes("lo")
        );

        let rx = 0, tx = 0;

        if (iface) {
            const netChart = await fetchWithRetry(
                `${NETDATA}/api/v1/data?chart=${iface}&after=-1&points=1&format=json`
            );

            const netRow = netChart?.data?.[0] || [];
            rx = netRow[1] || 0;
            tx = netRow[2] || 0;
        }

        // Temperature
        let temp = 0;
        try {
            const tempChart = await fetchWithRetry(
                `${NETDATA}/api/v1/data?chart=sensors.temperature_cpu_thermal-virtual-0_temp1_input&after=-1&points=1&format=json`
            );

            if (tempChart && tempChart.data && tempChart.data.length > 0) {
                temp = tempChart.data[0][1];
            }
        } catch (err) {}

        // Uptime
        const uptimeChart = await fetchWithRetry(
            `${NETDATA}/api/v1/data?chart=system.uptime&after=-1&points=1&format=json`
        );

        const uptime = uptimeChart?.data?.[0]?.[1] || 0;

        res.json({
            ok: true,
            cpu: cpuTotal,
            ram: ramPercent,
            disk: diskPercent,
            network: { rx, tx },
            uptime,
            temp
        });

    } catch (err) {
        res.json({ ok: false });
    }
});

/* ---------------------------------------------------------------------------
   Services
--------------------------------------------------------------------------- */
app.get("/api/services", async (req, res) => {
    exec("systemctl is-active earnbox-reset.service", (err, stdout) => {
        const status = stdout.trim() || "unknown";
        res.json({ resetService: status });
    });
});

/* ---------------------------------------------------------------------------
   Docker Containers
--------------------------------------------------------------------------- */
app.get("/api/containers", async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        res.json(containers);
    } catch (err) {
        console.error("Dockerode error:", err);
        res.json([]);
    }
});

app.post("/api/containers/:id/start", (req, res) => {
    exec(`docker start ${req.params.id}`, () => res.json({ ok: true }));
});

app.post("/api/containers/:id/stop", (req, res) => {
    exec(`docker stop ${req.params.id}`, () => res.json({ ok: true }));
});

app.post("/api/containers/:id/restart", (req, res) => {
    exec(`docker restart ${req.params.id}`, () => res.json({ ok: true }));
});

/* ---------------------------------------------------------------------------
   Container Logs
--------------------------------------------------------------------------- */
app.get("/api/containers/:id/logs", async (req, res) => {
    try {
        const c = docker.getContainer(req.params.id);
        const logs = await c.logs({
            stdout: true,
            stderr: true,
            tail: 200
        });

        res.json({
            logs: logs.toString("utf8").split("\n")
        });
    } catch (err) {
        console.error("Log error:", err);
        res.json({ logs: [] });
    }
});

/* ---------------------------------------------------------------------------
   Admin: Reset + Daily Reset
--------------------------------------------------------------------------- */
app.post("/api/admin/reset", (req, res) => {
    exec("systemctl restart earnbox-reset.service", () => {
        res.json({ ok: true });
    });
});

app.post("/api/admin/enable-daily-reset", (req, res) => {
    exec("systemctl enable --now earnbox-reset.timer", () => {
        res.json({ ok: true });
    });
});

/* ---------------------------------------------------------------------------
   Start Server
--------------------------------------------------------------------------- */
app.listen(3001, () => {
    console.log("Backend running on port 3001");
});
