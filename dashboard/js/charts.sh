const ChartsModule = (() => {

  // Draw a simple line chart using SVG
  function renderLineChart(containerId, points) {
    const el = document.getElementById(containerId);
    if (!el) return;

    const width = el.clientWidth || 320;
    const height = el.clientHeight || 200;
    const padding = 20;

    const max = Math.max(...points, 1);
    const min = Math.min(...points, 0);

    const svgNS = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("width", width);
    svg.setAttribute("height", height);

    const path = document.createElementNS(svgNS, "path");
    let d = "";

    points.forEach((v, i) => {
      const x = padding + (i / (points.length - 1 || 1)) * (width - padding * 2);
      const y = height - padding - ((v - min) / (max - min || 1)) * (height - padding * 2);
      d += (i === 0 ? "M" : "L") + x + " " + y + " ";
    });

    path.setAttribute("d", d);
    path.setAttribute("fill", "none");
    path.setAttribute("stroke", "rgba(168,85,247,0.9)");
    path.setAttribute("stroke-width", "2");

    svg.appendChild(path);
    el.innerHTML = "";
    el.appendChild(svg);
  }

  // Generate random data for placeholder charts
  function randomSeries(len, min, max) {
    const arr = [];
    for (let i = 0; i < len; i++) {
      arr.push(Math.random() * (max - min) + min);
    }
    return arr;
  }

  // --- FULL CHARTS PAGE ---
  function renderChartsPage() {
    const root = document.createElement("div");
    root.className = "grid grid-2";

    const cpuCard = document.createElement("div");
    cpuCard.className = "card";
    cpuCard.innerHTML = `
      <div class="card-header">
        <div class="card-title">CPU Load</div>
      </div>
      <div class="card-body">
        <div id="cpuChart" class="chart-container"></div>
      </div>
    `;
    root.appendChild(cpuCard);

    const tempCard = document.createElement("div");
    tempCard.className = "card";
    tempCard.innerHTML = `
      <div class="card-header">
        <div class="card-title">Temperature</div>
      </div>
      <div class="card-body">
        <div id="tempChart" class="chart-container"></div>
      </div>
    `;
    root.appendChild(tempCard);

    setTimeout(() => {
      renderLineChart("cpuChart", randomSeries(20, 5, 60));
      renderLineChart("tempChart", randomSeries(20, 40, 70));
    }, 0);

    return root;
  }

  // --- EARNINGS CHART ---
  function renderEarningsChart(containerId) {
    renderLineChart(containerId, randomSeries(14, 0.05, 0.4));
  }

  return {
    renderChartsPage,
    renderEarningsChart
  };
})();
