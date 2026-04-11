import express from "express";
import Docker from "dockerode";

const router = express.Router();
const docker = new Docker({ socketPath: "/var/run/docker.sock" });

router.get("/", async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });

        const result = containers.map(c => {
            const name = c.Names[0].replace("/", "");
            const status = c.State === "running" ? "running" : "stopped";

            // Detect exposed port (if any)
            let port = null;
            if (c.Ports && c.Ports.length > 0) {
                const p = c.Ports.find(p => p.PublicPort || p.PrivatePort);
                port = p?.PublicPort || p?.PrivatePort || null;
            }

            // Detect container type
            let type = "generic";
            let ui = true;
            let login_url = null;

            if (name.includes("pawns")) {
                type = "pawns";
                ui = false;
            }

            if (name.includes("honeygain")) {
                type = "honeygain";
                ui = false;
            }

            if (name.includes("portainer")) {
                type = "portainer";
                login_url = `http://${req.hostname}:9000`;
            }

            if (name.includes("netdata")) {
                type = "netdata";
                login_url = `http://${req.hostname}:19999`;
            }

            if (name.includes("nginx")) {
                type = "dashboard";
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

export default router;
