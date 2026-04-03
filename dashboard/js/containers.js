/* --------------------------------------------------
   CONTAINERS PAGE
-------------------------------------------------- */

function loadContainersPage() {
    content.innerHTML = `
        <div class="grid grid-3" id="containerGrid">
            <div class="card glass">
                <div class="card-title">Loading containers...</div>
            </div>
        </div>
    `;

    fetchContainers();
}

/* --------------------------------------------------
   FETCH CONTAINER LIST
-------------------------------------------------- */

function fetchContainers() {
    fetch("/api/containers")
        .then(res => res.json())
        .then(containers => {
            renderContainers(containers);
        })
        .catch(err => {
            console.error("Container API error:", err);
        });
}

/* --------------------------------------------------
   RENDER CONTAINER CARDS
-------------------------------------------------- */

function renderContainers(containers) {
    const grid = document.getElementById("containerGrid");

    if (!containers || containers.length === 0) {
        grid.innerHTML = `
            <div class="card glass">
                <div class="card-title">No containers found</div>
            </div>
        `;
        return;
    }

    grid.innerHTML = containers.map(c => `
        <div class="card glass">
            <div class="card-title">${c.name}</div>

            <div class="card-value neon" style="font-size:20px;">
                ${statusBadge(c.status)}
            </div>

            <div class="container-actions">
                ${actionButtons(c)}
            </div>
        </div>
    `).join("");
}

/* --------------------------------------------------
   STATUS BADGE
-------------------------------------------------- */

function statusBadge(status) {
    const running = status.toLowerCase().includes("up");

    return `
        <span class="badge ${running ? "badge-running" : "badge-stopped"}">
            ${running ? "Running" : "Stopped"}
        </span>
    `;
}

/* --------------------------------------------------
   ACTION BUTTONS
-------------------------------------------------- */

function actionButtons(c) {
    const running = c.status.toLowerCase().includes("up");

    return `
        <button class="btn neon-btn" onclick="restartContainer('${c.id}')">Restart</button>
        ${
            running
                ? `<button class="btn stop-btn" onclick="stopContainer('${c.id}')">Stop</button>`
                : `<button class="btn start-btn" onclick="startContainer('${c.id}')">Start</button>`
        }
    `;
}

/* --------------------------------------------------
   API ACTIONS
-------------------------------------------------- */

function restartContainer(id) {
    fetch(`/api/containers/${id}/restart`, { method: "POST" })
        .then(() => loadContainersPage());
}

function stopContainer(id) {
    fetch(`/api/containers/${id}/stop`, { method: "POST" })
        .then(() => loadContainersPage());
}

function startContainer(id) {
    fetch(`/api/containers/${id}/start`, { method: "POST" })
        .then(() => loadContainersPage());
}
