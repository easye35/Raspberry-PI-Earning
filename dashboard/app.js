const API_BASE = window.location.origin.replace(/:\d+$/, ":3001") || "http://localhost:3001";

async function fetchJson(path) {
  try {
    const res = await fetch(`${API_BASE}${path}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

function setText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}

async function refresh() {
  document.getElementById("last-update").textContent = `Last update: ${new Date().toLocaleTimeString()}`;

  const containers = await fetchJson("/api/system/containers");
  if (containers.ok) {
    const lines = containers.containers.map(
      (c) => `${c.Names}  |  ${c.Status}  |  ${c.Image}`
    );
    document.getElementById("system-containers").textContent = lines.join("\n") || "No containers.";
  } else {
    document.getElementById("system-containers").textContent = `Error: ${containers.error}`;
  }

  const earn = await fetchJson("/api/earnapp/status");
  if (earn.ok) {
    setText("earnapp-service", earn.service_status || "unknown");
    setText("earnapp-device", earn.device_id || "unknown");
    setText("earnapp-email", earn.email || "unknown");
    document.getElementById("earnapp-log").textContent =
      earn.log_tail || "(no log data)";
  } else {
    document.getElementById("earnapp-log").textContent = `Error: ${earn.error}`;
  }

  document.getElementById("honeygain-status").textContent =
    "See container status above (honeygain).";
  document.getElementById("pawns-status").textContent =
    "See container status above (pawns).";
}

async function restartEarnApp() {
  const btn = document.getElementById("earnapp-restart");
  btn.disabled = true;
  btn.textContent = "Restarting...";
  try {
    const res = await fetch(`${API_BASE}/api/earnapp/restart`, {
      method: "POST",
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    await refresh();
  } catch (e) {
    alert("Failed to restart EarnApp: " + e.message);
  } finally {
    btn.disabled = false;
    btn.textContent = "Restart EarnApp";
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document
    .getElementById("earnapp-restart")
    .addEventListener("click", restartEarnApp);

  refresh();
  setInterval(refresh, 30000);
});
