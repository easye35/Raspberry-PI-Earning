// Containers status (placeholder logic)

const ContainersModule = (() => {
  const knownContainers = [
    { name: "earnapp", label: "EarnApp", role: "Earnings" },
    { name: "honeygain", label: "Honeygain", role: "Earnings" },
    { name: "netdata", label: "Netdata", role: "Monitoring" },
    { name: "portainer", label: "Portainer", role: "Management" },
    { name: "watchtower", label: "Watchtower", role: "Updates" },
    { name: "nginx", label: "Nginx", role: "Dashboard" }
  ];

  function fakeStatus() {
    return {
      status: "running",
      restarts: Math.floor(Math.random() * 3),
      cpu: (Math.random() * 5).toFixed(1),
      mem: (Math.random() * 8).toFixed(1)
    };
  }

  function statusBadge(status) {
    if (status === "running") {
      return `<span class="badge badge-ok"><i class="fas fa-circle"></i> Running</span>`;
    }
    if (status === "restarting") {
      return `<span class="badge badge-warn"><i class="fas fa-rotate"></i> Restarting</span>`;
    }
    return `<span class="badge badge-err"><i class="fas fa-triangle-exclamation"></i> Error</span>`;
  }

  // --- SUMMARY CARD (Dashboard) ---
  function renderContainersSummaryCard() {
    const card = document.createElement("div");
    card.className = "card";

    const header = document.createElement("div");
    header.className = "card-header";
    header.innerHTML = `
      <div>
        <div class="card-title">Containers</div>
        <div class="card-subtitle">Core services</div>
      </div>
      <span class="badge badge-ok"><i class="fas fa-cubes"></i> ${knownContainers.length} tracked</span>
    `;
    card.appendChild(header);

    const body = document.createElement("div");
    body.className = "card-body";

    knownContainers.slice(0, 3).forEach(c => {
      const s = fakeStatus();
      const row = document.createElement("div");
      row.className = "metric-row";
      row.innerHTML = `
        <span class="metric-label">${c.label}</span>
        <span class="metric-value">${statusBadge(s.status)}</span>
      `;
      body.appendChild(row);
    });

    card.appendChild(body);
    return card;
  }

  // --- FULL PAGE ---
  function renderContainersPage() {
    const root = document.createElement("div");
    root.className = "card";

    const header = document.createElement("div");
    header.className = "card-header";
    header.innerHTML = `
      <div>
        <div class="card-title">Containers</div>
        <div class="card-subtitle">Tracked Docker services</div>
      </div>
      <button class="btn btn-primary" id="refreshContainers"><i class="fas fa-rotate"></i> Refresh</button>
    `;
    root.appendChild(header);

    const body = document.createElement("div");
    body.className = "card-body";

    const table = document.createElement("table");
    table.className = "table";
    table.innerHTML = `
      <thead>
        <tr>
          <th>Name</th>
          <th>Role</th>
          <th>Status</th>
          <th>CPU</th>
          <th>RAM</th>
          <th>Restarts</th>
        </tr>
      </thead>
      <tbody id="containersTableBody"></tbody>
    `;
    body.appendChild(table);
    root.appendChild(body);

    setTimeout(() => {
      populateTable();
      const btn = document.getElementById("refreshContainers");
      if (btn) btn.addEventListener("click", populateTable);
    }, 0);

    return root;
  }

  function populateTable() {
    const tbody = document.getElementById("containersTableBody");
    if (!tbody) return;
    tbody.innerHTML = "";

    knownContainers.forEach(c => {
      const s = fakeStatus();
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${c.label}</td>
        <td>${c.role}</td>
        <td>${statusBadge(s.status)}</td>
        <td>${s.cpu}%</td>
        <td>${s.mem}%</td>
        <td>${s.restarts}</td>
      `;
      tbody.appendChild(tr);
    });
  }

  return {
    renderContainersSummaryCard,
    renderContainersPage
  };
})();
