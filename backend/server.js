import express from 'express';
import cors from 'cors';
import servicesRouter from './routes/services.js';

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// Simple health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Main services API
app.use('/api/services', servicesRouter);

app.listen(PORT, () => {
  console.log(`Backend listening on port ${PORT}`);
});
