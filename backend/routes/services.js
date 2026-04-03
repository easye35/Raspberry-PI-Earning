import express from 'express';
import { listContainers, getContainer } from '../utils/docker.js';
import { updateNetworkUsage, getMonthlyNetworkUsage } from '../utils/usageStore.js';

const router = express.Router();

// GET /api/services
router.get('/', async (req, res) => {
  try {
    const containers = await listContainers();

    const results = await Promise.all(
      containers.map(async (c) => {
        const container = getContainer(c.Id);

        let stats;
        try {
          stats = await container.stats({ stream: false });
        } catch {
          stats = null;
        }

        let cpu = null;
        let memory = null;
        let rxBytes = 0;
        let txBytes = 0;

        if (stats) {
          // CPU calculation
          const cpuDelta =
            stats.cpu_stats.cpu_usage.total_usage -
            stats.precpu_stats.cpu_usage.total_usage;

          const systemDelta =
            stats.cpu_stats.system_cpu_usage -
            stats.precpu_stats.system_cpu_usage;

          if (cpuDelta > 0 && systemDelta > 0) {
            cpu = (cpuDelta / systemDelta) * stats.cpu_stats.online_cpus * 100;
          }

          memory = stats.memory_stats.usage ?? null;

          // Network totals
          const networks = stats.networks || {};
          for (const iface of Object.values(networks)) {
            rxBytes += iface.rx_bytes || 0;
            txBytes += iface.tx_bytes || 0;
          }

          // Update monthly usage
          const name = c.Names[0]?.replace(/^\//, '') || c.Id;
          updateNetworkUsage(name, rxBytes, txBytes);
        }

        return {
          id: c.Id,
          name: c.Names[0]?.replace(/^\//, '') || c.Id,
          image: c.Image,
          state: c.State,
          status: c.Status,
          cpu,
          memory,
          network: {
            rxBytes,
            txBytes
          }
        };
      })
    );

    res.json(results);
  } catch (err) {
    console.error('Error in /api/services:', err);
    res.status(500).json({ error: 'Failed to list services' });
  }
});

// GET /api/services/:name/network?period=month
router.get('/:name/network', (req, res) => {
  const { name } = req.params;
  const { period, month } = req.query;

  if (period !== 'month') {
    return res.status(400).json({ error: 'Only period=month is supported' });
  }

  const usage = getMonthlyNetworkUsage(name, month || null);

  res.json({
    name,
    period: 'month',
    month: month || 'current',
    rxBytes: usage.rx,
    txBytes: usage.tx
  });
});

export default router;
