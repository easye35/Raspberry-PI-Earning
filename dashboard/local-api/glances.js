async function loadGlances() {
    const el = document.getElementById("system-data");
    try {
        const res = await fetch("http://localhost:3001/glances");
        const data = await res.json();
        el.innerHTML = `<pre>${JSON.stringify(data, null, 2)}</pre>`;
    } catch (err) {
        el.innerHTML = "Error loading system metrics.";
    }
}
