function updateContainers(containers) {
  const root = document.getElementById("containers");
  root.innerHTML = "";

  Object.entries(containers).forEach(([name, state]) => {
    if (name === "_end") return;

    const cls = state === "running" ? "ok" : "err";

    root.innerHTML += `
      <div class="container-row">
        <span class="container-name">
          <span class="badge ${cls}">${state}</span> ${name}
        </span>
        <span>
          <button class="small" onclick="restartContainer('${name}')">Restart</button>
        </span>
      </div>`;
  });
}
