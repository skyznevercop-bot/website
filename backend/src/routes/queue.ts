import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { joinQueue, leaveQueue, getQueueStats } from "../services/matchmaking";

const router = Router();

/** POST /api/queue/join — Join a matchmaking queue. */
router.post("/join", requireAuth, async (req: AuthRequest, res) => {
  const { timeframe, bet } = req.body;

  if (!timeframe || typeof bet !== "number" || bet <= 0) {
    res.status(400).json({ error: "Invalid timeframe or bet amount" });
    return;
  }

  await joinQueue(req.userAddress!, timeframe, bet);
  res.json({ status: "queued", timeframe, bet });
});

/** DELETE /api/queue/leave — Leave a matchmaking queue. */
router.delete("/leave", requireAuth, async (req: AuthRequest, res) => {
  const { timeframe, bet } = req.body;
  await leaveQueue(req.userAddress!, timeframe, bet);
  res.json({ status: "left" });
});

/** GET /api/queue/stats — Get current queue statistics. */
router.get("/stats", async (_req, res) => {
  const stats = await getQueueStats();
  res.json({ queues: stats });
});

export default router;
