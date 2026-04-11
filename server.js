// ------------------------------------------------------------
// EarnBox Backend API
// ------------------------------------------------------------
import express from "express";
import Docker from "dockerode";
import cors from "cors";
import { exec } from "child_process";

const app = express();
const docker = new Docker({ socketPath: "/var/run/docker.sock" });

app.use(cors());
app.use(express.json());

// ------------------------------------------------------------
// ROOT
// ------------------------------------------------------------
app.get("/", (req, res) => {
    res.json({ status: "EarnBox backend running" });
});

// ------------------------------------------------------------
// CONTAINER AUTO-DISCOVERY
// ------------------------------------------------------------
app.get("/api/containers", async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });

        const result = containers.map(c => {
            const name = c.Names[0].replace("/", "");
            const status = c.State === "running" ? "running" : "stopped";

            // Detect port
            let port = null;
            if (c.Ports && c.Ports.length > 0) {
                const p = c.Ports.find(p => p.PublicPort || p.PrivatePort);
                port = p?.PublicPort || p?.PrivatePort || null;
            }

            // Type detection
            let type = "generic";
            let ui = false;
            let login_url = null;

            // Pawns
            if (name.includes("pawns")) {
                type = "pawns";
                ui = true;
                login_url = `http://${req.hostname}:9000/#/containers/${name}`;
            }

            // Honeygain
            if (name.includes("honeygain")) {
                type = "honeygain";
                ui = true;
                login_url = `http://${req.hostname}:9000/#/containers/${name}`;
            }

            // EarnApp
            if (name.includes("earnapp")) {
                type = "earnapp";
                ui = true;
                login_url = `http://${req.hostname}:9000/#/containers/${name}`;
            }

            // Portainer
            if (name.includes("portainer")) {
                type = "portainer";
                ui = true;
                login_url = `http://${req.hostname}:9000`;
            }

            // Netdata
            if (name.includes("netdata")) {
                type = "netdata";
                ui = true;
                login_url = `http://${req.hostname}:19999`;
            }

            // Dashboard (nginx)
            if (name.includes("nginx")) {
                type = "dashboard";
                ui = true;
                login_url = `http://${req.hostname}`;
            }

            return {
                name,
                type,
                status,
                ip: c.NetworkSettings?.Networks?.bridge?.IPAddress || "127.0.0.1",
                port,
                ui,
                login_url,
                last_seen: c.Status
            };
        });

        res.json(result);

    } catch (err) {
        console.error("Container discovery error:", err);
        res.status(500).json({ error: "Failed to read Docker containers" });
    }
});

// ------------------------------------------------------------
// ADMIN: Restart All Containers
// ------------------------------------------------------------
app.post("/api/admin/reset", (req, res) => {
    exec("docker restart $(docker ps -q)", (err) => {
        if (err) {
            console.error("Restart error:", err);
            return res.status(500).json({ error: "Failed to restart containers" });
        }
        res.json({ status: "ok" });
    });
});

// ------------------------------------------------------------
// ADMIN: Enable Daily Auto-Reset
// ------------------------------------------------------------
app.post("/api/admin/enable-daily-reset", (req, res) => {
    exec("sudo systemctl enable --now earnbox-reset.timer", (err) => {
        if (err) {
            console.error("Timer enable error:", err);
            return res.status(500).json({ error: "Failed to enable daily reset" });
        }
        res.json({ status: "enabled" });
    });
});

import fs from "fs";

// ------------------------------------------------------------
// ADMIN: Read .env credentials
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
// ADMIN: Update .env credentials
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
// ADMIN: Restart containers to apply new credentials
// ------------------------------------------------------------
app.post("/api/admin/apply-env", (req, res) => {
    exec("docker compose down && docker compose up -d", (err) => {
        if (err) {
            console.error("Restart error:", err);
            return res.status(500).json({ error: "Failed to restart containers" });
        }
        res.json({ status: "containers restarted" });
    });
});
// ------------------------------------------------------------
// START SERVER
// ------------------------------------------------------------
const PORT = 3001;
app.listen(PORT, () => {
    console.log(`EarnBox backend running on port ${PORT}`);
});
