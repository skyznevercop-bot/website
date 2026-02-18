import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { joinQueue, leaveQueue, getQueueStats } from "../services/matchmaking";

const router = Router();

/** POST /api/queue/join — Join a matchmaking queue. */
router.post("/join", requireAuth, async (req: AuthRequest, res) => {
  const { duration, bet } = req.body;

  if (!duration || typeof bet !== "number" || bet <= 0) {
    res.status(400).json({ error: "Invalid duration or bet amount" });
    return;
  }

  await joinQueue(req.userAddress!, duration, bet);
  res.json({ status: "queued", duration, bet });
});

/** DELETE /api/queue/leave — Leave a matchmaking queue. */
router.delete("/leave", requireAuth, async (req: AuthRequest, res) => {
  const { duration, bet } = req.body;
  await leaveQueue(req.userAddress!, duration, bet);
  res.json({ status: "left" });
});

/** Known duration labels in the same order as the frontend's AppConstants.durations. */
const DURATION_INDEX: Record<string, number> = {
  "15m": 0,
  "1h": 1,
  "4h": 2,
  "12h": 3,
  "24h": 4,
};

/** GET /api/queue/stats — Get current queue statistics. */
router.get("/stats", async (_req, res) => {
  const stats = await getQueueStats();

  // Transform into the shape the frontend expects:
  //   { index, size, avgWaitSeconds }
  // Aggregate across bet amounts per duration so each duration index
  // shows the total number of players searching.
  const byDuration = new Map<number, number>();
  for (const entry of stats) {
    const idx = DURATION_INDEX[entry.duration];
    if (idx == null) continue;
    byDuration.set(idx, (byDuration.get(idx) ?? 0) + entry.count);
  }

  const queues = Array.from(byDuration.entries()).map(([index, size]) => ({
    index,
    size,
    avgWaitSeconds: null, // not tracked yet
  }));

  res.json({ queues });
});

export default router;
