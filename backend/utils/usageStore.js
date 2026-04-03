import fs from 'fs';
import path from 'path';

const DATA_DIR = path.join(process.cwd(), 'data');
const USAGE_FILE = path.join(DATA_DIR, 'usage.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Load usage file
function loadUsage() {
  if (!fs.existsSync(USAGE_FILE)) return {};
  try {
    return JSON.parse(fs.readFileSync(USAGE_FILE, 'utf8'));
  } catch {
    return {};
  }
}

// Save usage file
function saveUsage(data) {
  fs.writeFileSync(USAGE_FILE, JSON.stringify(data, null, 2));
}

/**
 * usage schema:
 * {
 *   [containerName]: {
 *     lastRx: number,
 *     lastTx: number,
 *     months: {
 *       "2026-04": { rx: number, tx: number }
 *     }
 *   }
 * }
 */

export function updateNetworkUsage(containerName, rxBytes, txBytes) {
  const data = loadUsage();
  const now = new Date();
  const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  if (!data[containerName]) {
    data[containerName] = {
      lastRx: rxBytes,
      lastTx: txBytes,
      months: {}
    };
  }

  const entry = data[containerName];

  const deltaRx = rxBytes - (entry.lastRx ?? rxBytes);
  const deltaTx = txBytes - (entry.lastTx ?? txBytes);

  if (!entry.months[monthKey]) {
    entry.months[monthKey] = { rx: 0, tx: 0 };
  }

  if (deltaRx >= 0) entry.months[monthKey].rx += deltaRx;
  if (deltaTx >= 0) entry.months[monthKey].tx += deltaTx;

  entry.lastRx = rxBytes;
  entry.lastTx = txBytes;

  saveUsage(data);
}

export function getMonthlyNetworkUsage(containerName, monthKey = null) {
  const data = loadUsage();
  const entry = data[containerName];
  if (!entry) return { rx: 0, tx: 0 };

  if (!monthKey) {
    const now = new Date();
    monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  }

  const month = entry.months[monthKey];
  if (!month) return { rx: 0, tx: 0 };

  return month;
}
