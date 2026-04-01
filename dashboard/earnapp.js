function updateEarnApp(ea) {
  const root = document.getElementById("earnapp");
  root.innerHTML = "";

  if (!ea) return;

  let cls = "err";
  let text = "Not installed";

  if (ea.installed === "yes") {
    text = ea.status;
    cls = ea.status === "active" ? "ok" : "warn";
  }

  root.innerHTML = `
    <div class="container-row">
      <span class="container-name">
        <span class="badge ${cls}">${text}</span> EarnApp
      </span>
    </div>`;
}
