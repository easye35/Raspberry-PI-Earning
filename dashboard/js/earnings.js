/* --------------------------------------------------
   EARNINGS PAGE
-------------------------------------------------- */

function loadEarningsPage() {
    content.innerHTML = `
        <div class="grid grid-3">

            <div class="card glass">
                <div class="card-title">Today</div>
                <div id="earnToday" class="card-value neon">$0.00</div>
            </div>

            <div class="card glass">
                <div class="card-title">This Week</div>
                <div id="earnWeek" class="card-value neon">$0.00</div>
            </div>

            <div class="card glass">
                <div class="card-title">This Month</div>
                <div id="earnMonth" class="card-value neon">$0.00</div>
            </div>

            <div class="card glass">
                <div class="card-title">Lifetime</div>
                <div id="earnLifetime" class="card-value neon">$0.00</div>
            </div>

        </div>

        <div class="card glass" style="margin-top:30px;">
            <div class="card-title">Earnings History</div>
            <table class="table" id="earnHistoryTable">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Amount</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td colspan="2">Loading...</td></tr>
                </tbody>
            </table>
        </div>
    `;

    fetchEarnings();
}

/* --------------------------------------------------
   FETCH EARNINGS
-------------------------------------------------- */

function fetchEarnings() {
    fetch("/api/earnings")
        .then(res => res.json())
        .then(data => {
            updateEarningsCards(data);
            updateEarningsHistory(data.history);
        })
        .catch(err => {
            console.error("Earnings API error:", err);
        });
}

/* --------------------------------------------------
   UPDATE CARDS
-------------------------------------------------- */

function updateEarningsCards(data) {
    animateValue("earnToday", formatMoney(data.today));
    animateValue("earnWeek", formatMoney(data.week));
    animateValue("earnMonth", formatMoney(data.month));
    animateValue("earnLifetime", formatMoney(data.lifetime));
}

/* --------------------------------------------------
   UPDATE HISTORY TABLE
-------------------------------------------------- */

function updateEarningsHistory(history) {
    const table = document.querySelector("#earnHistoryTable tbody");

    if (!history || history.length === 0) {
        table.innerHTML = `<tr><td colspan="2">No earnings history found</td></tr>`;
        return;
    }

    table.innerHTML = history.map(row => `
        <tr>
            <td>${row.date}</td>
            <td>$${row.amount.toFixed(2)}</td>
        </tr>
    `).join("");
}

/* --------------------------------------------------
   HELPERS
-------------------------------------------------- */

function animateValue(id, value) {
    const el = document.getElementById(id);
    if (!el) return;

    el.textContent = value;

    // Neon pulse animation
    el.style.transition = "none";
    el.style.transform = "scale(1.1)";
    el.style.textShadow = "0 0 12px #00eaff";

    setTimeout(() => {
        el.style.transition = "transform 0.4s ease, text-shadow 0.4s ease";
        el.style.transform = "scale(1)";
        el.style.textShadow = "";
    }, 80);
}

function formatMoney(num) {
    return "$" + Number(num).toFixed(2);
}
