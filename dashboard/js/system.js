// System metrics + power status (placeholder logic)

const SystemModule = (() => {
  // Temporary fake metrics until real endpoints are wired
  function fakeMetric(min, max, decimals = 1) {
    const v = Math.random() * (max - min) + min;
    return v.toFixed(decimals);
  }

  // --- SUMMARY CARD (Dashboard) ---
  function renderSystemSummaryCard() {
    const card = document.createElement("div");
    card.className = "card";

    const header = document.createElement("div");
    header.className = "card-header";
    header.innerHTML = `
      <div>
        <div class="card-title">System Status</div>
        <div class="card-subtitle">Raspberry Pi • Earnbox</div>
      </div>
      <span class="badge badge-ok"><i class="fas fa-circle"></i> Healthy</span>
    `;
    card.appendChild(header);

    const body = document.createElement("div");
    body.className = "card-body";

    body.innerHTML = `
      <div class="metric-row">
        <span class="metric-label">CPU Load</span>
        <span class="metric-value">${fakeMetric(5, 45)}%</span>
      </div>
      <div class="metric-row">
        <span class="metric-label">RAM</span>
        <span class="metric-value">${fakeMetric(20, 70)}%</span>
      </div>
      <div class="metric-row">
        <span class="metric-label">Disk</span>
        <span class="metric-value">${fakeMetric(30, 80)}%</span>
      </div>
      <div class="metric-row">
        <span class="metric-label">Temp</span>
        <span class="metric-value">${fakeMetric(40, 65)}°C</span>
      </div>
      <div class="metric-row">
        <span class="metric-label">Uptime</span>
        <span class="metric-value">~${fakeMetric(1, 48, 0)} hrs</span>
      </div>
    `;

    card.appendChild(body);
    return card;
  }

  // --- SYSTEM PAGE ---
  function renderSystemPage() {
    const root = document.createElement("div");
    root.className = "grid grid-2";

    root.appendChild(renderSystemSummaryCard());

    const card = document.createElement("div");
    card.className = "card";
    card.innerHTML = `
      <div class="card-header">
        <div class="card-title">System Detail</div>
      </div>
      <div class="card-body">
        <div class="metric-row">
          <span class="metric-label">CPU Cores</span>
          <span class="metric-value">4</span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Arch</span>
          <span class="metric-value">arm64</span>
        </div>
        <div class="metric-row">
          <span class="metric-label">OS</span>
          <span class="metric-value">Raspberry Pi OS</span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Kernel</span>
          <span class="metric-value">Linux</span>
        </div>
      </div>
    `;
    root.appendChild(card);

    return root;
  }

  // --- POWER PAGE ---
  function renderPowerPage() {
    const root = document.createElement("div");
    root.className = "grid grid-2";

    const card = document.createElement("div");
    card.className = "card";
    card.innerHTML = `
      <div class="card-header">
        <div class="card-title">Power & Throttle</div>
      </div>
      <div class="card-body">
        <div class="metric-row">
          <span class="metric-label">Undervoltage</span>
          <span class="metric-value"><span class="badge badge-ok"><i class="fas fa-bolt"></i> None</span></span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Freq Capped</span>
          <span class="metric-value"><span class="badge badge-ok"><i class="fas fa-gauge-high"></i> No</span></span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Throttled</span>
          <span class="metric-value"><span class="badge badge-ok"><i class="fas fa-temperature-low"></i> No</span></span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Soft Temp Limit</span>
          <span class="metric-value"><span class="badge badge-ok"><i class="fas fa-fire"></i> Not reached</span></span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Raw Flags</span>
          <span class="metric-value"><span class="metric-pill"><i class="fas fa-code"></i>0x0</span></span>
        </div>
      </div>
    `;
    root.appendChild(card);

    return root;
  }

  return {
    renderSystemSummaryCard,
    renderSystemPage,
    renderPowerPage
  };
})();
