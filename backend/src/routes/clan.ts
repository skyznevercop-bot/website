import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { clansRef, getUser, updateUser } from "../services/firebase";

const router = Router();

// ── Helpers ──────────────────────────────────────────────────────────────────

interface MemberStats {
  address: string;
  gamerTag: string;
  role: string;
  wins: number;
  losses: number;
  ties: number;
  totalPnl: number;
  currentStreak: number;
  gamesPlayed: number;
  joinedAt: string;
}

/** Fetch full stats for every member in a clan. */
async function buildMembers(
  membersObj: Record<string, { role: string; joinedAt: number }>
): Promise<MemberStats[]> {
  const addresses = Object.keys(membersObj);
  return Promise.all(
    addresses.map(async (addr) => {
      const u = await getUser(addr);
      return {
        address: addr,
        gamerTag: u?.gamerTag || addr.slice(0, 8),
        role: membersObj[addr].role,
        wins: u?.wins || 0,
        losses: u?.losses || 0,
        ties: u?.ties || 0,
        totalPnl: u?.totalPnl || 0,
        currentStreak: u?.currentStreak || 0,
        gamesPlayed: u?.gamesPlayed || 0,
        joinedAt: new Date(membersObj[addr].joinedAt).toISOString(),
      };
    })
  );
}

/** Compute aggregated stats from a list of members. */
function computeAggregates(members: MemberStats[]) {
  const totalWins = members.reduce((s, m) => s + m.wins, 0);
  const totalLosses = members.reduce((s, m) => s + m.losses, 0);
  const totalTies = members.reduce((s, m) => s + m.ties, 0);
  const totalPnl = members.reduce((s, m) => s + m.totalPnl, 0);
  const totalGamesPlayed = members.reduce((s, m) => s + m.gamesPlayed, 0);
  const bestStreak = members.length > 0
    ? Math.max(...members.map((m) => m.currentStreak))
    : 0;
  const winRate =
    totalGamesPlayed > 0 ? Math.round((totalWins / totalGamesPlayed) * 100) : 0;

  return { totalWins, totalLosses, totalTies, totalPnl, totalGamesPlayed, bestStreak, winRate };
}

// ── Routes ───────────────────────────────────────────────────────────────────

/** GET /api/clan — List all clans with computed stats. */
router.get("/", async (req, res) => {
  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
  const sortBy = (req.query.sortBy as string) || "winRate";

  const snap = await clansRef.once("value");
  if (!snap.exists()) {
    res.json({ clans: [], total: 0, page, limit });
    return;
  }

  const entries: Array<{ key: string; val: Record<string, unknown> }> = [];
  snap.forEach((child) => {
    entries.push({ key: child.key!, val: child.val() });
  });

  const clans = await Promise.all(
    entries.map(async ({ key, val: c }) => {
      const membersObj = (c.members || {}) as Record<string, { role: string; joinedAt: number }>;
      const members = await buildMembers(membersObj);
      const agg = computeAggregates(members);

      return {
        id: key,
        name: c.name as string,
        tag: c.tag as string,
        description: (c.description as string) || "",
        leaderAddress: c.leaderAddress as string,
        memberCount: members.length,
        maxMembers: (c.maxMembers as number) || 50,
        totalWins: agg.totalWins,
        totalLosses: agg.totalLosses,
        totalPnl: agg.totalPnl,
        totalGamesPlayed: agg.totalGamesPlayed,
        winRate: agg.winRate,
        createdAt: new Date(c.createdAt as number).toISOString(),
      };
    })
  );

  // Sort by chosen criterion.
  switch (sortBy) {
    case "pnl":
      clans.sort((a, b) => b.totalPnl - a.totalPnl);
      break;
    case "wins":
      clans.sort((a, b) => b.totalWins - a.totalWins);
      break;
    case "members":
      clans.sort((a, b) => b.memberCount - a.memberCount);
      break;
    case "winRate":
    default:
      clans.sort((a, b) => b.winRate - a.winRate);
      break;
  }

  const total = clans.length;
  const start = (page - 1) * limit;

  res.json({
    clans: clans.slice(start, start + limit),
    total,
    page,
    limit,
  });
});

/** GET /api/clan/my — Get the authenticated user's clan with full stats. */
router.get("/my", requireAuth, async (req: AuthRequest, res) => {
  const user = await getUser(req.userAddress!);
  if (!user || !user.clanId) {
    res.json({ clan: null });
    return;
  }

  const snap = await clansRef.child(user.clanId).once("value");
  if (!snap.exists()) {
    // clanId is stale — clean it up.
    await updateUser(req.userAddress!, { clanId: null });
    res.json({ clan: null });
    return;
  }

  const clan = snap.val();
  const membersObj = clan.members || {};
  const members = await buildMembers(membersObj);
  const agg = computeAggregates(members);

  res.json({
    clan: {
      id: user.clanId,
      name: clan.name,
      tag: clan.tag,
      description: clan.description || "",
      leaderAddress: clan.leaderAddress,
      memberCount: members.length,
      maxMembers: clan.maxMembers || 50,
      totalWins: agg.totalWins,
      totalLosses: agg.totalLosses,
      totalTies: agg.totalTies,
      totalPnl: agg.totalPnl,
      totalGamesPlayed: agg.totalGamesPlayed,
      bestStreak: agg.bestStreak,
      winRate: agg.winRate,
      createdAt: new Date(clan.createdAt).toISOString(),
      members,
    },
  });
});

/** GET /api/clan/:id — Get clan details with full stats. */
router.get("/:id", async (req, res) => {
  const snap = await clansRef.child(req.params.id).once("value");

  if (!snap.exists()) {
    res.status(404).json({ error: "Clan not found" });
    return;
  }

  const clan = snap.val();
  const membersObj = clan.members || {};
  const members = await buildMembers(membersObj);
  const agg = computeAggregates(members);

  res.json({
    id: req.params.id,
    name: clan.name,
    tag: clan.tag,
    description: clan.description || "",
    leaderAddress: clan.leaderAddress,
    memberCount: members.length,
    maxMembers: clan.maxMembers || 50,
    totalWins: agg.totalWins,
    totalLosses: agg.totalLosses,
    totalTies: agg.totalTies,
    totalPnl: agg.totalPnl,
    totalGamesPlayed: agg.totalGamesPlayed,
    bestStreak: agg.bestStreak,
    winRate: agg.winRate,
    createdAt: new Date(clan.createdAt).toISOString(),
    members,
  });
});

/** POST /api/clan — Create a new clan. */
router.post("/", requireAuth, async (req: AuthRequest, res) => {
  const { name, tag, description } = req.body;

  if (!name || !tag || name.length > 30 || tag.length > 5) {
    res.status(400).json({ error: "Name (max 30) and tag (max 5) required" });
    return;
  }

  // Check if user is already in a clan via their user record.
  const user = await getUser(req.userAddress!);
  if (user?.clanId) {
    res.status(409).json({ error: "Already in a clan" });
    return;
  }

  const ref = clansRef.push();
  const now = Date.now();
  await ref.set({
    name,
    tag: tag.toUpperCase(),
    description: description || null,
    leaderAddress: req.userAddress!,
    maxMembers: 50,
    createdAt: now,
    members: {
      [req.userAddress!]: {
        role: "LEADER",
        joinedAt: now,
      },
    },
  });

  // Track clan membership on user record.
  await updateUser(req.userAddress!, { clanId: ref.key! });

  res.json({
    id: ref.key,
    name,
    tag: tag.toUpperCase(),
    description: description || "",
    createdAt: new Date(now).toISOString(),
  });
});

/** POST /api/clan/:id/join — Join a clan. */
router.post("/:id/join", requireAuth, async (req: AuthRequest, res) => {
  // Check if already in a clan via user record.
  const user = await getUser(req.userAddress!);
  if (user?.clanId) {
    res.status(409).json({ error: "Already in a clan" });
    return;
  }

  const clanSnap = await clansRef.child(req.params.id).once("value");
  if (!clanSnap.exists()) {
    res.status(404).json({ error: "Clan not found" });
    return;
  }

  const clan = clanSnap.val();
  const memberCount = clan.members ? Object.keys(clan.members).length : 0;

  if (memberCount >= (clan.maxMembers || 50)) {
    res.status(400).json({ error: "Clan is full" });
    return;
  }

  await clansRef.child(req.params.id).child("members").child(req.userAddress!).set({
    role: "MEMBER",
    joinedAt: Date.now(),
  });

  // Track clan membership on user record.
  await updateUser(req.userAddress!, { clanId: req.params.id });

  res.json({ status: "joined", clanId: req.params.id });
});

/** DELETE /api/clan/:id/leave — Leave a clan. */
router.delete("/:id/leave", requireAuth, async (req: AuthRequest, res) => {
  const clanSnap = await clansRef.child(req.params.id).once("value");
  if (!clanSnap.exists()) {
    res.status(404).json({ error: "Clan not found" });
    return;
  }

  const clan = clanSnap.val();
  if (!clan.members || !clan.members[req.userAddress!]) {
    res.status(404).json({ error: "Not in this clan" });
    return;
  }

  const memberRole = clan.members[req.userAddress!].role;

  if (memberRole === "LEADER") {
    const otherMembers = Object.entries(clan.members).filter(
      ([addr]) => addr !== req.userAddress
    );

    if (otherMembers.length > 0) {
      // Transfer leadership.
      const [newLeaderAddr] = otherMembers[0];
      await clansRef.child(req.params.id).update({
        leaderAddress: newLeaderAddr,
      });
      await clansRef
        .child(req.params.id)
        .child("members")
        .child(newLeaderAddr)
        .update({ role: "LEADER" });
    } else {
      // Dissolve clan.
      await clansRef.child(req.params.id).remove();
      await updateUser(req.userAddress!, { clanId: null });
      res.json({ status: "clan_dissolved" });
      return;
    }
  }

  // Remove member.
  await clansRef
    .child(req.params.id)
    .child("members")
    .child(req.userAddress!)
    .remove();

  // Clear clan membership on user record.
  await updateUser(req.userAddress!, { clanId: null });

  res.json({ status: "left" });
});

export default router;
