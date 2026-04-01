async function fetchDiagnostics() {
  const res = await fetch("http://" + window.location.hostname + ":7000");
  return await res.json();
}

function runDiagnostics() {
  const box = document.getElementById("diag-output");
  box.style.display = "block";
  box.textContent = "Running diagnostics...";

  fetchDiagnostics()
    .then(data => box.textContent = JSON.stringify(data, null, 2))
    .catch(err => box.textContent = "Error: " + err);
}

setInterval(async () => {
  try {
    const data = await fetchDiagnostics();

    document.getElementById("cpu").textContent = data.system.cpu_load;
    document.getElementById("ram").textContent = data.system.ram;
    document.getElementById("disk").textContent = data.system.disk;
    document.getElementById("temp").textContent = data.system.temp;
    document.getElementById("uptime").textContent = data.system.uptime;

    updateContainers(data.containers);
    updateHealth(data.healthchecks);
    updateEarnApp(data.earnapp);
    updateChartFromDiag(data);

  } catch (err) {
    console.log("Diagnostics fetch failed:", err);
  }
}, 5000);
