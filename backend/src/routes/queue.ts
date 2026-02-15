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

/** GET /api/queue/stats — Get current queue statistics. */
router.get("/stats", async (_req, res) => {
  const stats = await getQueueStats();
  res.json({ queues: stats });
});

export default router;
