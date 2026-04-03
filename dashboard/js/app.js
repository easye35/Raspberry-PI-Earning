/* --------------------------------------------------
   GLOBAL STATE
-------------------------------------------------- */
let currentPage = "dashboard";
let refreshInterval = null;
const REFRESH_RATE = 5000; // 5 seconds

/* --------------------------------------------------
   DOM ELEMENTS
-------------------------------------------------- */
const sidebar = document.getElementById("sidebar");
const openSidebarBtn = document.getElementById("openSidebar");
const closeSidebarBtn = document.getElementById("closeSidebar");
const pageTitle = document.getElementById("pageTitle");
const content = document.getElementById("content");
const refreshStatus = document.getElementById("refreshStatus");
const themeToggle = document.getElementById("themeToggle");

/* --------------------------------------------------
   SIDEBAR TOGGLE
-------------------------------------------------- */
openSidebarBtn.addEventListener("click", () => {
    sidebar.classList.remove("hidden");
});

closeSidebarBtn.addEventListener("click", () => {
    sidebar.classList.add("hidden");
});

/* --------------------------------------------------
   THEME TOGGLE
-------------------------------------------------- */
themeToggle.addEventListener("click", () => {
    document.body.classList.toggle("light");
});

/* --------------------------------------------------
   PAGE LOADING ENGINE
-------------------------------------------------- */
function loadPage(page) {
    currentPage = page;
    pageTitle.textContent = capitalize(page);

    // Highlight active nav item
    document.querySelectorAll(".nav-item").forEach(item => {
        item.classList.remove("active");
        if (item.dataset.page === page) {
            item.classList.add("active");
        }
    });

    // Load page content
    switch (page) {
        case "dashboard":
            loadDashboardPage();
            break;
        case "containers":
            loadContainersPage();
            break;
        case "system":
            loadSystemPage();
            break;
        case "power":
            loadPowerPage();
            break;
        case "earnings":
            loadEarningsPage();
            break;
        case "charts":
            loadChartsPage();
            break;
        case "settings":
            loadSettingsPage();
            break;
        default:
            content.innerHTML = "<p>Page not found.</p>";
    }

    restartAutoRefresh();
}

/* --------------------------------------------------
   AUTO REFRESH
-------------------------------------------------- */
function restartAutoRefresh() {
    if (refreshInterval) clearInterval(refreshInterval);

    refreshInterval = setInterval(() => {
        loadPage(currentPage);
    }, REFRESH_RATE);

    refreshStatus.textContent = `Auto-refresh: ${REFRESH_RATE / 1000}s`;
}

/* --------------------------------------------------
   NAVIGATION CLICK HANDLERS
-------------------------------------------------- */
document.querySelectorAll(".nav-item").forEach(item => {
    item.addEventListener("click", () => {
        loadPage(item.dataset.page);
        sidebar.classList.add("hidden");
    });
});

/* --------------------------------------------------
   UTILS
-------------------------------------------------- */
function capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

/* --------------------------------------------------
   INITIAL LOAD
-------------------------------------------------- */
loadPage("dashboard");
