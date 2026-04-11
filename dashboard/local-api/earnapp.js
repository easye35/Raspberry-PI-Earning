async function loadEarnApp() {
    const el = document.getElementById("earnapp-data");
    try {
        const res = await fetch("http://localhost:3001/earnapp");
        const data = await res.json();
        el.innerHTML = `<pre>${JSON.stringify(data, null, 2)}</pre>`;
    } catch (err) {
        el.innerHTML = "Error loading EarnApp data.";
    }
}
