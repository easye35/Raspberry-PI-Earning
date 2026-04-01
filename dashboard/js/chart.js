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
