async function fetchEarnApp() {
    try {
        const res = await fetch("http://earning-api:3001/api/earnapp/status");
        return await res.json();
    } catch (err) {
        return { ok: false, error: err.toString() };
    }
}
