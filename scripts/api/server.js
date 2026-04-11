const express = require("express");
const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");

const { getEarnAppStatus } = require("./utils/earnapp");

const app = express();
const PORT = process.env.PORT || 3001;

app.use(express.json());

function run(cmd) {
  return new Promise((resolve, reject) => {
    exec(cmd, { maxBuffer: 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) return reject(stderr || err.message);
      resolve(stdout.trim());
    });
  });
}

app.get("/api/system/containers", async (req, res) => {
  try {
    const out = await run("docker ps --format '{{json .}}'");
    const lines = out ? out.split("\n") : [];
    const containers = lines.filter(Boolean).map((l) => JSON.parse(l));
    res.json({ ok: true, containers });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

app.get("/api/earnapp/status", async (req, res) => {
  try {
    const status = await getEarnAppStatus({ logLines: 20 });
    res.json({ ok: true, ...status });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

app.post("/api/earnapp/restart", async (req, res) => {
  try {
    await run("sudo systemctl restart earnapp.service");
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

app.get("/api/health", (req, res) => {
  res.json({ ok: true, ts: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`[api] Listening on port ${PORT}`);
});
