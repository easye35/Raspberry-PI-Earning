/* -------------------------------------------------------------
   SIDEBAR TOGGLE
------------------------------------------------------------- */

const sidebar = document.getElementById("sidebar");
const content = document.getElementById("content");
const menuBtn = document.getElementById("menuBtn");

menuBtn.addEventListener("click", () => {
    sidebar.classList.toggle("open");
    content.classList.toggle("shift");
});

/* -------------------------------------------------------------
   PAGE LOADER
------------------------------------------------------------- */

function loadPage(page) {
    document.getElementById("pageTitle").innerText =
        page.charAt(0).toUpperCase() + page.slice(1);

    // Hide all panels
    document.querySelectorAll(".panel").forEach(p => p.style.display = "none");

    // Show selected panel
    const pageId = page + "Page";
    const panel = document.getElementById(pageId);

    if (panel) {
        panel.style.display = "block";
    }

    // Trigger page-specific loads
    if (page === "dashboard") loadDashboard();
    if (page === "containers") refreshContainers();
}

/* -------------------------------------------------------------
   DASHBOARD DATA LOADER
------------------------------------------------------------- */

async function loadDashboard() {
    try {
        const sysRes = await fetch("/api/system");
        const sys = await sysRes.json();

        const earnRes = await fetch("/api/earnings");
        const earn = await earnRes.json();

        const contRes = await fetch("/api/containers");
        const cont = await contRes.json();

        // System
        document.getElementById("dashCpu").innerText = sys.cpu + "%";
        document.getElementById("dashRam").innerText = sys.ram + "%";
        document.getElementById("dashDisk").innerText = sys.disk + "%";
        document.getElementById("dashTemp").innerText = sys.temp + "°C";
        document.getElementById("dashUptime").innerText = sys.uptime;

        // Containers
        document.getElementById("dashContainerCount").innerText = cont.length;

        const list = document.getElementById("dashContainerList");
        list.innerHTML = "";
        cont.slice(0, 3).forEach(c => {
            const li = document.createElement("li");
            li.innerText = `${c.name} • ${c.status}`;
            list.appendChild(li);
        });

        // Earnings
        document.getElementById("dashEarnApp").innerText = "$" + earn.earnapp;
        document.getElementById("dashHoneygain").innerText = "$" + earn.honeygain;
        document.getElementById("dashToday").innerText = "$" + earn.today;
        document.getElementById("dashWeek").innerText = "$" + earn.week;

    } catch (err) {
        console.error("Dashboard load failed:", err);
    }
}

/* -------------------------------------------------------------
   CONTAINERS TABLE LOADER
------------------------------------------------------------- */

async function refreshContainers() {
    try {
        const res = await fetch("/api/containers");
        const data = await res.json();

        const tbody = document.getElementById("containerTableBody");
        tbody.innerHTML = "";

        data.forEach(c => {
            const row = document.createElement("tr");

            row.innerHTML = `
                <td>${c.name}</td>
                <td>${c.role}</td>
                <td>${c.status}</td>
                <td>${c.cpu}%</td>
                <td>${c.ram}%</td>
                <td>${c.restarts}</td>
            `;

            tbody.appendChild(row);
        });

    } catch (err) {
        console.error("Error loading containers:", err);
    }
}

/* -------------------------------------------------------------
   POWER ACTIONS
------------------------------------------------------------- */

function shutdown() {
    fetch("/api/power/shutdown", { method: "POST" });
    alert("Shutdown command sent.");
}

function reboot() {
    fetch("/api/power/reboot", { method: "POST" });
    alert("Reboot command sent.");
}

/* -------------------------------------------------------------
   INITIAL LOAD
------------------------------------------------------------- */

window.onload = () => {
    loadPage("dashboard");
};
