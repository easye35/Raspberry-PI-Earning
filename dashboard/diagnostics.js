<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Pi Earning Appliance Dashboard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <style>
    :root {
      --bg: #050816;
      --card: #0b1020;
      --text: #f9fafb;
      --accent: #2563eb;
      --accent-soft: #1d4ed8;
      --ok: #16a34a;
      --warn: #ca8a04;
      --err: #dc2626;
    }

    body.light {
      --bg: #f3f4f6;
      --card: #ffffff;
      --text: #111827;
      --accent: #2563eb;
      --accent-soft: #1d4ed8;
      --ok: #16a34a;
      --warn: #ca8a04;
      --err: #dc2626;
    }

    body {
      font-family: system-ui, sans-serif;
      background: var(--bg);
      color: var(--text);
      padding: 16px;
      margin: 0;
      transition: background 0.2s, color 0.2s;
    }

    header {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 8px;
      margin-bottom: 16px;
    }

    h1 {
      margin: 0;
      font-size: 1.4rem;
    }

    .toggle-btn {
      padding: 6px 12px;
      border-radius: 999px;
      border: 1px solid var(--accent-soft);
      background: transparent;
      color: var(--text);
      cursor: pointer;
      font-size: 0.85rem;
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 12px;
    }

    .card {
      background: var(--card);
      padding: 14px;
      border-radius: 10px;
      box-shadow: 0 0 10px #0004;
    }

    .card h2 {
      margin-top: 0;
      font-size: 1.05rem;
      margin-bottom: 8px;
    }

    .badge {
      padding: 3px 8px;
      border-radius: 999px;
      font-size: 0.75rem;
      font-weight: 600;
      color: #f9fafb;
      display: inline-block;
      margin-right: 6px;
    }

    .ok { background: var(--ok); }
    .warn { background: var(--warn); }
    .err { background: var(--err); }

    button {
      padding: 8px 14px;
      background: var(--accent);
      color: white;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      font-size: 0.85rem;
    }

    button.small {
      padding: 4px 8px;
      font-size: 0.75rem;
      margin-left: 4px;
    }

    button:active {
      transform: translateY(1px);
    }

    pre {
      background: var(--card);
      padding: 10px;
      border-radius: 8px;
      white-space: pre-wrap;
      margin-top: 10px;
      max-height: 220px;
      overflow: auto;
      font-size: 0.8rem;
    }

    .container-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 0.9rem;
      margin-bottom: 4px;
    }

    .container-name {
      flex: 1;
    }

    iframe {
      width: 100%;
      height: 260px;
      border: none;
      border-radius: 8px;
      background: #000;
    }

    canvas {
      width: 100%;
      height: 160px;
      background: #020617;
      border-radius: 8px;
    }

    .earn-row {
      display: flex;
      justify-content: space-between;
      font-size: 0.9rem;
      margin-bottom: 4px;
    }

    @media (max-width: 600px) {
      header {
        flex-direction: column;
        align-items: flex-start;
      }
    }
  </style>
</head>

<body class="dark">
<header>
  <h1>Raspberry Pi Earning Appliance</h1>
  <button class="toggle-btn" onclick="toggleTheme()">Toggle Dark / Light</button>
</header>

<div class="grid">
  <div class="card">
    <h2>System Status</h2>
    <p><strong>CPU Load:</strong> <span id="cpu"></span></p>
    <p><strong>RAM:</strong> <span id="ram"></span></p>
    <p><strong>Disk:</strong> <span id="disk"></span></p>
    <p><strong>Temp:</strong> <span id="temp"></span></p>
    <p><strong>Uptime:</strong> <span id="uptime"></span></p>
  </div>

  <div class="card">
    <h2>Containers</h2>
    <div id="containers"></div>
  </div>

  <div class="card">
    <h2>Healthchecks</h2>
    <div id="health"></div>
  </div>

  <div class="card">
    <h2>Earnings (Stub)</h2>
    <div id="earnings">
      <div class="earn-row">
        <span>Honeygain:</span>
        <span id="hg-earn">$0.00</span>
      </div>
      <div class="earn-row">
        <span>Pawns:</span>
        <span id="pawns-earn">$0.00</span>
      </div>
      <small>API wiring TBD — placeholder values for now.</small>
    </div>
  </div>

  <div class="card">
    <h2>CPU / RAM Over Time</h2>
    <canvas id="chart"></canvas>
  </div>

  <div class="card">
    <h2>Logs (Dozzle)</h2>
    <iframe src="http://<?php echo $_SERVER['HTTP_HOST'] ?? 'localhost'; ?>:9999"></iframe>
    <small>Make sure Dozzle is exposed on port 9999 in compose.yml.</small>
  </div>

  <div class="card">
    <h2>Actions</h2>
    <button onclick="runDiagnostics()">Run Diagnostics</button>
    <pre id="diag-output" style="display:none;"></pre>
  </div>
</div>

<script>
let theme = 'dark';
function toggleTheme() {
  theme = theme === 'dark' ? 'light' : 'dark';
  document.body.className = theme;
}

async function fetchDiag() {
  try {
    const res = await fetch("http://" + window.location.hostname + ":7000");
    const data = await res.json();

    document.getElementById("cpu").textContent = data.system.cpu_load;
    document.getElementById("ram").textContent = data.system.ram;
    document.getElementById("disk").textContent = data.system.disk;
    document.getElementById("temp").textContent = data.system.temp;
    document.getElementById("uptime").textContent = data.system.uptime;
    updatePower(data.power);
    let contHTML = "";
    for (const [name, state] of Object.entries(data.containers)) {
      if (name === "_end") continue;
      const cls = state === "running" ? "ok" : "err";
      contHTML += `
        <div class="container-row">
          <span class="container-name">
            <span class="badge ${cls}">${state}</span> ${name}
          </span>
          <span>
            <button class="small" onclick="restartContainer('${name}')">Restart</button>
          </span>
        </div>`;
    }
    document.getElementById("containers").innerHTML = contHTML;

    let healthHTML = "";
    for (const [name, state] of Object.entries(data.healthchecks)) {
      if (name === "_end") continue;
      const cls = state === "healthy" ? "ok" : "warn";
      healthHTML += `<p><span class="badge ${cls}">${state}</span> ${name}</p>`;
    }
    document.getElementById("health").innerHTML = healthHTML;

    updateChartFromDiag(data);

  } catch (err) {
    console.log("Diagnostics fetch failed:", err);
  }
}

function updatePower(power) {
  if (!power) return;

  document.getElementById("p-undervolt").textContent = power.undervoltage;
  document.getElementById("p-capped").textContent = power.frequency_capped;
  document.getElementById("p-throttled").textContent = power.throttled;
  document.getElementById("p-soft").textContent = power.soft_temp_limit;
  document.getElementById("p-raw").textContent = power.raw;
}

function runDiagnostics() {
  const box = document.getElementById("diag-output");
  box.style.display = "block";
  box.textContent = "Running diagnostics...";

  fetch("http://" + window.location.hostname + ":7000")
    .then(r => r.json())
    .then(data => box.textContent = JSON.stringify(data, null, 2))
    .catch(err => box.textContent = "Error: " + err);
}

// NOTE: restartContainer assumes you later expose a small API or use a reverse proxy.
// For now, it's a placeholder that just logs intent.
function restartContainer(name) {
  alert("Restart request for container: " + name + "\n\nWire this to a backend endpoint when ready.");
}

// Simple CPU/RAM chart (no external libs)
const chartCanvas = document.getElementById("chart");
const ctx = chartCanvas.getContext("2d");
let cpuPoints = [];
let ramPoints = [];
let maxPoints = 30;

function parseCpuLoad(str) {
  if (!str) return 0;
  const parts = str.split(",");
  const last = parts[parts.length - 1].trim();
  const val = parseFloat(last);
  return isNaN(val) ? 0 : val;
}

function parseRamUsage(str) {
  if (!str) return 0;
  const parts = str.split("/");
  if (parts.length < 2) return 0;
  const used = parseFloat(parts[0]);
  const total = parseFloat(parts[1]);
  if (isNaN(used) || isNaN(total) || total === 0) return 0;
  return (used / total) * 100;
}

function updateChartFromDiag(data) {
  const cpu = parseCpuLoad(data.system.cpu_load);
  const ram = parseRamUsage(data.system.ram);

  cpuPoints.push(cpu);
  ramPoints.push(ram);
  if (cpuPoints.length > maxPoints) cpuPoints.shift();
  if (ramPoints.length > maxPoints) ramPoints.shift();

  drawChart();
}

function drawChart() {
  const w = chartCanvas.width;
  const h = chartCanvas.height;
  ctx.clearRect(0, 0, w, h);

  ctx.strokeStyle = "#4b5563";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(0, h - 20);
  ctx.lineTo(w, h - 20);
  ctx.stroke();

  const drawLine = (points, color) => {
    if (points.length < 2) return;
    const step = w / (maxPoints - 1 || 1);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    points.forEach((val, idx) => {
      const x = idx * step;
      const y = h - 20 - (val / 100) * (h - 40);
      if (idx === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
  };

  drawLine(cpuPoints, "#22c55e");
  drawLine(ramPoints, "#3b82f6");

  ctx.fillStyle = "#e5e7eb";
  ctx.font = "10px system-ui";
  ctx.fillText("CPU", 8, 12);
  ctx.fillText("RAM", 40, 12);
}

setInterval(fetchDiag, 5000);
fetchDiag();
</script>

</body>
</html>
