// Core App Router + Layout Controller

const App = (() => {
  const contentEl = document.getElementById("content");
  const pageTitleEl = document.getElementById("pageTitle");
  const sidebarEl = document.getElementById("sidebar");
  const openSidebarBtn = document.getElementById("openSidebar");
  const closeSidebarBtn = document.getElementById("closeSidebar");
  const themeToggleBtn = document.getElementById("themeToggle");
  const refreshStatusEl = document.getElementById("refreshStatus");

  const state = {
    currentPage: "dashboard",
    autoRefreshMs: 5000,
    autoRefreshTimer: null,
    theme: "auto"
  };

  const pages = {
    dashboard: renderDashboard,
    containers: renderContainersPage,
    system: renderSystemPage,
    power: renderPowerPage,
    earnings: renderEarningsPage,
    charts: renderChartsPage,
    settings: renderSettingsPage
  };

  function init() {
    initTheme();
    initSidebar();
    initRouter();
    startAutoRefresh();
  }

  function initSidebar() {
    openSidebarBtn.addEventListener("click", () => {
      sidebarEl.classList.add("open");
    });
    closeSidebarBtn.addEventListener("click", () => {
      sidebarEl.classList.remove("open");
    });

    document.querySelectorAll(".nav-item").forEach(item => {
      item.addEventListener("click", () => {
        sidebarEl.classList.remove("open");
      });
    });
  }

  function initTheme() {
    const saved = localStorage.getItem("earnbox-theme") || "auto";
    setTheme(saved);

    themeToggleBtn.addEventListener("click", () => {
      const next = state.theme === "auto" ? "dark" :
                   state.theme === "dark" ? "light" : "auto";
      setTheme(next);
    });
  }

  function setTheme(mode) {
    state.theme = mode;
    localStorage.setItem("earnbox-theme", mode);

    if (mode === "auto") {
      document.documentElement.setAttribute("data-theme",
        window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark"
      );
    } else {
      document.documentElement.setAttribute("data-theme", mode);
    }
  }

  function initRouter() {
    window.addEventListener("hashchange", handleRoute);
    if (!location.hash) {
      location.hash = "#/dashboard";
    } else {
      handleRoute();
    }
  }

  function handleRoute() {
    const hash = location.hash.replace("#/", "") || "dashboard";
    state.currentPage = pages[hash] ? hash : "dashboard";
    updateNavActive();
    renderCurrentPage();
  }

  function updateNavActive() {
    document.querySelectorAll(".nav-item").forEach(item => {
      const page = item.getAttribute("data-page");
      item.classList.toggle("active", page === state.currentPage);
    });
  }

  function renderCurrentPage() {
    const pageFn = pages[state.currentPage] || pages.dashboard;
    pageTitleEl.textContent = capitalize(state.currentPage);
    contentEl.innerHTML = "";
    const pageNode = pageFn();
    if (pageNode) {
      pageNode.classList.add("fade-in");
      contentEl.appendChild(pageNode);
    }
  }

  function startAutoRefresh() {
    if (state.autoRefreshTimer) clearInterval(state.autoRefreshTimer);
    refreshStatusEl.textContent = `Auto-refresh: ${state.autoRefreshMs / 1000}s`;
    state.autoRefreshTimer = setInterval(() => {
      renderCurrentPage();
    }, state.autoRefreshMs);
  }

  function setAutoRefresh(ms) {
    state.autoRefreshMs = ms;
    startAutoRefresh();
  }

  function capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  // Page renderers

  function renderDashboard() {
    const root = document.createElement("div");
    root.className = "grid grid-3";

    root.appendChild(SystemModule.renderSystemSummaryCard());
    root.appendChild(ContainersModule.renderContainersSummaryCard());
    root.appendChild(EarningsModule.renderEarningsSummaryCard());

    return root;
  }

  function renderContainersPage() {
    return ContainersModule.renderContainersPage();
  }

  function renderSystemPage() {
    return SystemModule.renderSystemPage();
  }

  function renderPowerPage() {
    return SystemModule.renderPowerPage();
  }

  function renderEarningsPage() {
    return EarningsModule.renderEarningsPage();
  }

  function renderChartsPage() {
    return ChartsModule.renderChartsPage();
  }

  function renderSettingsPage() {
    const root = document.createElement("div");
    root.className = "grid grid-2";

    const card = document.createElement("div");
    card.className = "card";

    const header = document.createElement("div");
    header.className = "card-header";
    header.innerHTML = `<div class="card-title">Settings</div>`;
    card.appendChild(header);

    const body = document.createElement("div");
    body.className = "card-body";

    const themeRow = document.createElement("div");
    themeRow.className = "settings-row";
    themeRow.innerHTML = `
      <div class="settings-label">Theme mode</div>
      <div class="settings-control">
        <span id="themeModeLabel" class="metric-pill"><i class="fas fa-circle-half-stroke"></i><span>${state.theme}</span></span>
      </div>
    `;
    body.appendChild(themeRow);

    const refreshRow = document.createElement("div");
    refreshRow.className = "settings-row";
    refreshRow.innerHTML = `
      <div class="settings-label">Auto-refresh interval</div>
      <div class="settings-control">
        <button class="btn" data-ms="3000">3s</button>
        <button class="btn" data-ms="5000">5s</button>
        <button class="btn" data-ms="10000">10s</button>
      </div>
    `;
    body.appendChild(refreshRow);

    const versionRow = document.createElement("div");
    versionRow.className = "settings-row";
    versionRow.innerHTML = `
      <div class="settings-label">Earnbox UI version</div>
      <div class="settings-control">
        <span class="metric-pill"><i class="fas fa-code-branch"></i><span>v1.0.0</span></span>
      </div>
    `;
    body.appendChild(versionRow);

    card.appendChild(body);
    root.appendChild(card);

    setTimeout(() => {
      root.querySelectorAll("[data-ms]").forEach(btn => {
        btn.addEventListener("click", () => {
          const ms = parseInt(btn.getAttribute("data-ms"), 10);
          setAutoRefresh(ms);
        });
      });
      const themeLabel = root.querySelector("#themeModeLabel span:last-child");
      if (themeLabel) themeLabel.textContent = state.theme;
    }, 0);

    return root;
  }

  return { init };
})();

document.addEventListener("DOMContentLoaded", () => {
  App.init();
});
