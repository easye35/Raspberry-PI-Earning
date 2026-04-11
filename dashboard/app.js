const content = document.getElementById("content");
const sidebar = document.getElementById("sidebar");
const main = document.getElementById("main");
const toggleBtn = document.getElementById("toggleSidebar");

toggleBtn.onclick = () => {
    sidebar.classList.toggle("collapsed");
    main.classList.toggle("collapsed");
};

document.querySelectorAll(".nav a").forEach(a => {
    a.onclick = () => loadSection(a.dataset.section);
});

async function loadSection(section) {
    if (section === "home") return renderHome();
    if (section === "earnapp") return renderEarnApp();
    if (section === "containers") return renderContainers();
    if (section === "system") return renderSystem();
    if (section === "logins") return renderLogins();
}

async function renderHome() {
    const gl = await fetchGlances();
    const ea = await fetchEarnApp();

    content.innerHTML = `
        <div class="grid">
            <div class="card"><h2>Honeygain</h2><p>Container: honeygain</p></div>
            <div class="card"><h2>Pawns</h2><p>Container: pawns</p></div>
            <div class="card"><h2>EarnApp</h2><p>Status: ${ea.service_status}</p></div>
            <div class="card"><h2>System</h2><p>CPU: ${gl.cpu?.total}%</p></div>
        </div>
    `;
}

async function renderEarnApp() {
    const ea = await fetchEarnApp();

    content.innerHTML = `
        <div class="card">
            <h2>EarnApp Native</h2>
            <p>Status: ${ea.service_status}</p>
            <p>Device ID: ${ea.device_id}</p>
            <p>Email: ${ea.email}</p>
            <pre>${ea.log_tail || "No logs"}</pre>
        </div>
    `;
}

async function renderContainers() {
    const gl = await fetchGlances();
    const containers = parseContainers(gl);

    content.innerHTML = `
        <div class="grid">
            ${containers.map(c => `
                <div class="card">
                    <h3>${c.name}</h3>
                    <p>Status: ${c.status}</p>
                    <p>CPU: ${c.cpu}%</p>
                    <p>RAM: ${c.mem}%</p>
                    <p>Uptime: ${c.uptime}</p>
                </div>
            `).join("")}
        </div>
    `;
}

async function renderSystem() {
    const gl = await fetchGlances();

    content.innerHTML = `
        <div class="grid">
            <div class="card"><h2>CPU</h2><p>${gl.cpu.total}%</p></div>
            <div class="card"><h2>RAM</h2><p>${gl.mem.used} / ${gl.mem.total}</p></div>
            <div class="card"><h2>Disk</h2><p>${gl.fs[0].used} / ${gl.fs[0].size}</p></div>
            <div class="card"><h2>Network</h2><p>RX: ${gl.network.rx} TX: ${gl.network.tx}</p></div>
        </div>
    `;
}

function renderLogins() {
    content.innerHTML = `
        <div class="grid">
            <a class="card" href="https://dashboard.honeygain.com">Honeygain Login</a>
            <a class="card" href="https://pawns.app">Pawns Login</a>
            <a class="card" href="https://earnapp.com">EarnApp Login</a>
            <a class="card" href="http://dozzle:8080">Dozzle</a>
            <a class="card" href="http://glances:61208">Glances</a>
            <a class="card" href="http://portainer:9000">Portainer</a>
        </div>
    `;
}

loadSection("home");
setInterval(() => loadSection("home"), 5000);
