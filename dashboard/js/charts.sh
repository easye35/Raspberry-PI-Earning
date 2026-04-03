// ADVANCED CANVAS CHART ENGINE -----------------------------------------

function drawChart(canvasId, data, options = {}) {
    const canvas = document.getElementById(canvasId);
    const ctx = canvas.getContext("2d");

    const {
        color = "#00aaff",
        gridColor = "#333",
        animate = true,
        tooltip = true
    } = options;

    const width = canvas.width;
    const height = canvas.height;

    ctx.clearRect(0, 0, width, height);

    const max = Math.max(...data, 1);
    const stepX = width / (data.length - 1);

    // GRIDLINES ---------------------------------------------------------
    ctx.strokeStyle = gridColor;
    ctx.lineWidth = 1;

    for (let i = 0; i <= 5; i++) {
        const y = (height / 5) * i;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
    }

    // LINE --------------------------------------------------------------
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();

    data.forEach((value, i) => {
        const x = i * stepX;
        const y = height - (value / max) * height;

        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
    });

    ctx.stroke();

    // TOOLTIP -----------------------------------------------------------
    if (tooltip) {
        canvas.onmousemove = (e) => {
            const rect = canvas.getBoundingClientRect();
            const mouseX = e.clientX - rect.left;

            const index = Math.round(mouseX / stepX);
            const value = data[index];

            if (value !== undefined) {
                ctx.clearRect(0, 0, width, height);
                drawChart(canvasId, data, { color, gridColor, animate: false, tooltip: false });

                ctx.fillStyle = "#fff";
                ctx.font = "14px Arial";
                ctx.fillText(value, mouseX + 10, 20);

                ctx.beginPath();
                ctx.arc(index * stepX, height - (value / max) * height, 4, 0, Math.PI * 2);
                ctx.fillStyle = color;
                ctx.fill();
            }
        };
    }
}

// DATA BUFFERS ---------------------------------------------------------

let cpuHistory = [];
let ramHistory = [];
let earningsHistory = [];

// UPDATE LOOP ----------------------------------------------------------

async function updateCharts() {
    try {
        const res = await fetch("/api/system");
        const sys = await res.json();

        cpuHistory.push(sys.cpu);
        ramHistory.push(sys.ram);
        earningsHistory.push(sys.earnings);

        if (cpuHistory.length > 50) cpuHistory.shift();
        if (ramHistory.length > 50) ramHistory.shift();
        if (earningsHistory.length > 50) earningsHistory.shift();

        drawChart("cpuChart", cpuHistory, { color: "#00aaff" });
        drawChart("ramChart", ramHistory, { color: "#ffaa00" });
        drawChart("earningsChart", earningsHistory, { color: "#00ff88" });

    } catch (err) {
        console.error("Chart update failed:", err);
    }
}

setInterval(updateCharts, 3000);
