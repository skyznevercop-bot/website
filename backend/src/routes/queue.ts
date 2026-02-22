import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { joinQueue, leaveQueue, getQueueStats } from "../services/matchmaking";
import { VALID_DURATIONS, VALID_BETS, isValidDuration, isValidBet } from "../utils/validation";
import { getOnlinePlayerCount } from "../ws/rooms";
import { usersRef, matchesRef } from "../services/firebase";

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
  "5m": 0,
  "15m": 1,
  "1h": 2,
  "4h": 3,
  "24h": 4,
};

// ── Cached platform stats (refreshed every 60s) ────────────────────
let _cachedPlatformStats: { totalPlayers: number; totalMatches: number; totalVolume: number } | null = null;
let _platformStatsCachedAt = 0;
const STATS_CACHE_MS = 60_000;

async function getPlatformStats() {
  const now = Date.now();
  if (_cachedPlatformStats && now - _platformStatsCachedAt < STATS_CACHE_MS) {
    return _cachedPlatformStats;
  }

  const [usersSnap, matchesSnap] = await Promise.all([
    usersRef.once("value"),
    matchesRef.orderByChild("status").equalTo("completed").once("value"),
  ]);

  const totalPlayers = usersSnap.numChildren();
  let totalMatches = 0;
  let totalVolume = 0;

  if (matchesSnap.exists()) {
    matchesSnap.forEach((child) => {
      totalMatches++;
      const m = child.val();
      totalVolume += (m.betAmount ?? 0) * 2; // both players' bets
    });
  }

  _cachedPlatformStats = { totalPlayers, totalMatches, totalVolume };
  _platformStatsCachedAt = now;
  return _cachedPlatformStats;
}

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

  // Include real platform stats.
  let platformStats = { totalPlayers: 0, totalMatches: 0, totalVolume: 0 };
  try {
    platformStats = await getPlatformStats();
  } catch (err) {
    console.error("[Queue] Platform stats error:", err);
  }

  res.json({
    queues,
    onlinePlayers: getOnlinePlayerCount(),
    ...platformStats,
  });
});

export default router;
