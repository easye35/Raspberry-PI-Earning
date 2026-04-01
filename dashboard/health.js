function updateHealth(health) {
  const root = document.getElementById("health");
  root.innerHTML = "";

  Object.entries(health).forEach(([name, state]) => {
    if (name === "_end") return;

    const cls = state === "healthy" ? "ok" : "warn";
    root.innerHTML += `<p><span class="badge ${cls}">${state}</span> ${name}</p>`;
  });
}
