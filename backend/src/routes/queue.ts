import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { joinQueue, leaveQueue, getQueueStats } from "../services/matchmaking";
import { VALID_DURATIONS, VALID_BETS, isValidDuration, isValidBet } from "../utils/validation";

const router = Router();

/** POST /api/queue/join — Join a matchmaking queue (freezes bet amount). */
router.post("/join", requireAuth, async (req: AuthRequest, res) => {
  const { duration, bet } = req.body;

  if (!isValidDuration(duration)) {
    res.status(400).json({ error: `Invalid duration. Allowed: ${VALID_DURATIONS.join(", ")}` });
    return;
  }
  if (!isValidBet(bet)) {
    res.status(400).json({ error: `Invalid bet amount. Allowed: $${VALID_BETS.join(", $")}` });
    return;
  }

  const success = await joinQueue(req.userAddress!, duration, bet);
  if (!success) {
    res.status(400).json({ error: "Insufficient balance" });
    return;
  }

  res.json({ status: "queued", duration, bet });
});

/** DELETE /api/queue/leave — Leave a matchmaking queue (unfreezes bet). */
router.delete("/leave", requireAuth, async (req: AuthRequest, res) => {
  const { duration, bet } = req.body;

  if (!isValidDuration(duration) || !isValidBet(bet)) {
    res.status(400).json({ error: "Invalid duration or bet amount" });
    return;
  }

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

  const byDuration = new Map<number, number>();
  for (const entry of stats) {
    const idx = DURATION_INDEX[entry.duration];
    if (idx == null) continue;
    byDuration.set(idx, (byDuration.get(idx) ?? 0) + entry.count);
  }

  const queues = Array.from(byDuration.entries()).map(([index, size]) => ({
    index,
    size,
    avgWaitSeconds: null,
  }));

  res.json({ queues });
});

export default router;
