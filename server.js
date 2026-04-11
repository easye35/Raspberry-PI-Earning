import express from "express";
import fs from "fs";
import path from "path";
import { exec } from "child_process";
import { fileURLToPath } from "url";

const app = express();
app.use(express.json());

// Resolve __dirname for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ------------------------------------------------------------
// STATIC DASHBOARD
// ------------------------------------------------------------
app.use(express.static(path.join(__dirname, "dashboard")));

// ------------------------------------------------------------
// API: Container Auto‑Discovery
// ------------------------------------------------------------
app.get("/api/containers", (req, res) => {
    exec("docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}'", (err, stdout) => {
        if (err) return res.json([]);

        const lines = stdout.trim().split("\n");
        const containers = lines.map(line => {
            const [name, statusRaw, ports] = line.split("|");

            const status = statusRaw.includes("Up") ? "running" : "stopped";

            // Determine type
            let type = "generic";
            if (name.includes("pawns")) type = "pawns";
            if (name.includes("honeygain")) type = "honeygain";
            if (name.includes("earnapp")) type = "earnapp";

            // Determine UI port
            let port = null;
            if (ports && ports.includes("0.0.0.0")) {
                const match = ports.match(/0\.0\.0\.0:(\d+)/);
                if (match) port = match[1];
            }

            // Login URL
            let login_url = null;
            if (port) login_url = `http://localhost:${port}`;

            return {
                name,
                type,
                status,
                port,
                ui: !!port,
                login_url
            };
        });

        res.json(containers);
    });
});

// ------------------------------------------------------------
// ADMIN: Restart All Containers
// ------------------------------------------------------------
app.post("/api/admin/reset", (req, res) => {
    exec("docker compose down && docker compose up -d", err => {
        if (err) return res.status(500).json({ error: "Failed to restart containers" });
        res.json({ status: "ok" });
    });
});

// ------------------------------------------------------------
// ADMIN: Enable Daily Reset Timer
// ------------------------------------------------------------
app.post("/api/admin/enable-daily-reset", (req, res) => {
    exec("sudo systemctl enable --now earnbox-reset.timer", err => {
        if (err) return res.status(500).json({ error: "Failed to enable timer" });
        res.json({ status: "enabled" });
    });
});

// ------------------------------------------------------------
// ADMIN: Read .env
// ------------------------------------------------------------
app.get("/api/admin/env", (req, res) => {
    try {
        const env = fs.readFileSync("modules/.env", "utf8");
        const lines = env.split("\n");

        const data = {};
        for (const line of lines) {
            if (line.includes("=")) {
                const [key, value] = line.split("=");
                data[key.trim()] = value.trim();
            }
        }

        res.json(data);
    } catch (err) {
        res.status(500).json({ error: "Failed to read .env" });
    }
});

// ------------------------------------------------------------
// ADMIN: Write .env
// ------------------------------------------------------------
app.post("/api/admin/env", (req, res) => {
    try {
        let output = "";
        for (const [key, value] of Object.entries(req.body)) {
            output += `${key}=${value}\n`;
        }

        fs.writeFileSync("modules/.env", output);
        res.json({ status: "updated" });

    } catch (err) {
        res.status(500).json({ error: "Failed to write .env" });
    }
});

// ------------------------------------------------------------
// ADMIN: Apply .env + Restart Containers
// ------------------------------------------------------------
app.post("/api/admin/apply-env", (req, res) => {
    exec("docker compose down && docker compose up -d", err => {
        if (err) return res.status(500).json({ error: "Failed to restart containers" });
        res.json({ status: "containers restarted" });
    });
});

// ------------------------------------------------------------
// FALLBACK: Serve Dashboard SPA
// ------------------------------------------------------------
app.get("*", (req, res) => {
    res.sendFile(path.join(__dirname, "dashboard", "index.html"));
});

// ------------------------------------------------------------
// START SERVER
// ------------------------------------------------------------
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`EarnBox backend running on port ${PORT}`);
});
