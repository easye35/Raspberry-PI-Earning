async function fetchGlances() {
    try {
        const res = await fetch("http://glances:61208/api/3/");
        return await res.json();
    } catch (err) {
        return { error: true, message: err.toString() };
    }
}
