async function loadContainers() {
    const el = document.getElementById("container-data");
    try {
        const res = await fetch("http://localhost:3001/containers");
        const data = await res.json();
        el.innerHTML = `<pre>${JSON.stringify(data, null, 2)}</pre>`;
    } catch (err) {
        el.innerHTML = "Error loading containers.";
    }
}
