function parseContainers(glancesData) {
    if (!glancesData || !glancesData.docker) return [];

    return glancesData.docker.map(c => ({
        name: c.Name,
        status: c.Status,
        cpu: c.cpu_percent,
        mem: c.mem_percent,
        uptime: c.uptime
    }));
}
