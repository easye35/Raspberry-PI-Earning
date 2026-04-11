const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");

function readJsonSafe(p) {
  try {
    if (!fs.existsSync(p)) return null;
    const raw = fs.readFileSync(p, "utf8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function tailFile(p, lines = 20) {
  return new Promise((resolve) => {
    if (!fs.existsSync(p)) return resolve("");
    exec(`tail -n ${lines} "${p}"`, { maxBuffer: 1024 * 1024 }, (err, stdout) => {
      if (err) return resolve("");
      resolve(stdout.trim());
    });
  });
}

function systemctlStatus(unit) {
  return new Promise((resolve) => {
    exec(`systemctl is-active ${unit}`, (err, stdout) => {
      if (err) return resolve("unknown");
      resolve(stdout.trim());
    });
  });
}

async function getEarnAppStatus({ logLines = 20 } = {}) {
  const devicePath = "/etc/earnapp/device.json";
  const credPath = "/etc/earnapp/credentials.json";
  const logPath = "/var/log/earnapp/earnapp.log";

  const device = readJsonSafe(devicePath);
  const creds = readJsonSafe(credPath);
  const logTail = await tailFile(logPath, logLines);
  const serviceStatus = await systemctlStatus("earnapp.service");

  return {
    service_status: serviceStatus,
    device_id: device?.device_id || device?.id || null,
    email: creds?.email || null,
    log_tail: logTail,
    has_device_json: !!device,
    has_credentials_json: !!creds,
    has_log: fs.existsSync(logPath),
  };
}

module.exports = {
  getEarnAppStatus,
};
