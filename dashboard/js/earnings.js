// Earnings (placeholder logic)

const EarningsModule = (() => {
  function fakeEarnings() {
    return {
      earnapp: (Math.random() * 2).toFixed(2),
      honeygain: (Math.random() * 1.5).toFixed(2),
      daily: (Math.random() * 0.2).toFixed(2),
      weekly: (Math.random() * 1.4).toFixed(2)
    };
  }

  // --- SUMMARY CARD (Dashboard) ---
  function renderEarningsSummaryCard() {
    const e = fakeEarnings();

    const card = document.createElement("div");
    card.className = "card";

    const header = document.createElement("div");
    header.className = "card-header";
    header.innerHTML = `
      <div>
        <div class="card-title">Earnings</div>
        <div class="card-subtitle">EarnApp + Honeygain</div>
      </div>
      <span class="badge badge-ok"><i class="fas fa-coins"></i> Live</span>
    `;
    card.appendChild(header);

    const body = document.createElement("div");
    body.className = "card-body";

    body.innerHTML = `
      <div class="metric-row">
        <span class="metric-label">EarnApp</span>
        <span class="metric-value">$${e.earnapp}</span>
      </div>
      <div class="metric-row">
        <span class="metric-label">Honeygain</span>
        <span class="metric-value">$${e.honeygain}</span>
      </div>
      <div class="metric-row">
        <span class="metric-label">Today</span>
        <span class="metric-value">$${e.daily}</span>
      </div>
      <div class="metric-row">
        <span class="metric-label">Last 7 days</span>
        <span class="metric-value">$${e.weekly}</span>
      </div>
    `;

    card.appendChild(body);
    return card;
  }

  // --- FULL PAGE ---
  function renderEarningsPage() {
    const e = fakeEarnings();

    const root = document.createElement("div");
    root.className = "grid grid-2";

    const card = document.createElement("div");
    card.className = "card";
    card.innerHTML = `
      <div class="card-header">
        <div class="card-title">Earnings Overview</div>
      </div>
      <div class="card-body">
        <div class="metric-row">
          <span class="metric-label">EarnApp (est.)</span>
          <span class="metric-value">$${e.earnapp}</span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Honeygain (est.)</span>
          <span class="metric-value">$${e.honeygain}</span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Today</span>
          <span class="metric-value">$${e.daily}</span>
        </div>
        <div class="metric-row">
          <span class="metric-label">Last 7 days</span>
          <span class="metric-value">$${e.weekly}</span>
        </div>
      </div>
    `;
    root.appendChild(card);

    const chartCard = document.createElement("div");
    chartCard.className = "card";
    chartCard.innerHTML = `
      <div class="card-header">
        <div class="card-title">Earnings History</div>
      </div>
      <div class="card-body">
        <div id="earningsChart" class="chart-container"></div>
      </div>
    `;
    root.appendChild(chartCard);

    setTimeout(() => {
      ChartsModule.renderEarningsChart("earningsChart");
    }, 0);

    return root;
  }

  return {
    renderEarningsSummaryCard,
    renderEarningsPage
  };
})();
