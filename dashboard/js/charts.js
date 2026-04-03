/* --------------------------------------------------
   CHARTS PAGE
-------------------------------------------------- */

function loadChartsPage() {
    content.innerHTML = `
        <div class="card glass">
            <div class="card-title">Earnings Trend</div>
            <canvas id="earnChart" class="chart-box"></canvas>
        </div>
    `;

    fetchChartData();
}

/* --------------------------------------------------
   FETCH CHART DATA
-------------------------------------------------- */

function fetchChartData() {
    fetch("/api/earnings/trend")
        .then(res => res.json())
        .then(data => {
            renderNeonChart(data);
        })
        .catch(err => {
            console.error("Chart API error:", err);
        });
}

/* --------------------------------------------------
   RENDER NEON LINE CHART
-------------------------------------------------- */

function renderNeonChart(data) {
    const canvas = document.getElementById("earnChart");
    const ctx = canvas.getContext("2d");

    const labels = data.map(x => x.date);
    const values = data.map(x => x.amount);

    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Neon glow
    ctx.shadowBlur = 12;
    ctx.shadowColor = "#00eaff";

    // Line style
    ctx.strokeStyle = "#00eaff";
    ctx.lineWidth = 3;

    // Normalize values
    const max = Math.max(...values) || 1;
    const min = Math.min(...values) || 0;

    const padding = 30;
    const w = canvas.width - padding * 2;
    const h = canvas.height - padding * 2;

    const points = values.map((v, i) => {
        const x = padding + (i / (values.length - 1)) * w;
        const y = padding + h - ((v - min) / (max - min)) * h;
        return { x, y };
    });

    // Draw line
    ctx.beginPath();
    points.forEach((p, i) => {
        if (i === 0) ctx.moveTo(p.x, p.y);
        else ctx.lineTo(p.x, p.y);
    });
    ctx.stroke();

    // Draw glowing points
    points.forEach(p => {
        ctx.beginPath();
        ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
        ctx.fillStyle = "#00eaff";
        ctx.fill();
    });
}
