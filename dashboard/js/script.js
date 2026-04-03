// SIDEBAR TOGGLE --------------------------------------------------

const sidebar = document.getElementById("sidebar");
const content = document.getElementById("content");
const menuBtn = document.getElementById("menuBtn");

menuBtn.addEventListener("click", () => {
    sidebar.classList.toggle("open");
    content.classList.toggle("shift");
});

// PAGE LOADER -----------------------------------------------------

function loadPage(page) {
    document.getElementById("chartsPage").style.display = "none";
document.querySelector(".panel").style.display = "none";

if (page === "charts") {
    document.getElementById("chartsPage").style.display = "block";
} else {
    document.querySelector(".panel").style.display = "block";
}
    document.getElementById("pageTitle").innerText =
        page.charAt(0).toUpperCase() + page.slice(1);

    // Placeholder for future page loading
    console.log("Loading page:", page);
}

// CONTAINER REFRESH ----------------------------------------------

async function refreshContainers() {
    console.log("Refreshing containers...");

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
                <td>${c.cpu}</td>
                <td>${c.ram}</td>
                <td>${c.restarts}</td>
            `;

            tbody.appendChild(row);
        });

    } catch (err) {
        console.error("Error loading containers:", err);
    }
}
