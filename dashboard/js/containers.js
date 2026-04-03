async function loadContainers() {
  const tableBody = document.querySelector("#containersTable tbody");
  tableBody.innerHTML = "<tr><td colspan='6'>Loading...</td></tr>";

  try {
    const res = await fetch("/api/services");
    const data = await res.json();

    tableBody.innerHTML = "";

    data.forEach(c => {
      const row = document.createElement("tr");

      row.innerHTML = `
        <td>${c.name}</td>
        <td>${c.role || "—"}</td>
        <td class="${c.state === "running" ? "ok" : "bad"}">${c.state}</td>
        <td>${c.cpu ? c.cpu.toFixed(1) + "%" : "—"}</td>
        <td>${c.memory ? (c.memory / 1024 / 1024).toFixed(1) + " MB" : "—"}</td>
        <td>${c.restarts || 0}</td>
      `;

      tableBody.appendChild(row);
    });
  } catch (err) {
    tableBody.innerHTML = "<tr><td colspan='6'>Error loading data</td></tr>";
  }
}

document.getElementById("refreshBtn").onclick = loadContainers;

loadContainers();
