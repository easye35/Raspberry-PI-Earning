import express from "express";
import cors from "cors";
import bodyParser from "body-parser";
import { getEarnAppStatus, restartEarnApp } from "./utils/earnapp.js";

const app = express();
app.use(cors());
app.use(bodyParser.json());

app.get("/api/earnapp/status", async (req, res) => {
  try {
    const status = await getEarnAppStatus();
    res.json({ ok: true, status });
  } catch (err) {
    res.json({ ok: false, error: err.message });
  }
});

app.post("/api/earnapp/restart", async (req, res) => {
  try {
    await restartEarnApp();
    res.json({ ok: true });
  } catch (err) {
    res.json({ ok: false, error: err.message });
  }
});

app.listen(3001, () => {
  console.log("Earning API running on port 3001");
});
