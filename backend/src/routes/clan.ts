import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { clansRef, getUser } from "../services/firebase";

const router = Router();

/** GET /api/clan — List all clans. */
router.get("/", async (req, res) => {
  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

  const snap = await clansRef.once("value");
  if (!snap.exists()) {
    res.json({ clans: [], total: 0, page, limit });
    return;
  }

  const clans: Array<Record<string, unknown>> = [];
  snap.forEach((child) => {
    const c = child.val();
    const members = c.members ? Object.keys(c.members) : [];
    clans.push({
      id: child.key,
      name: c.name,
      tag: c.tag,
      description: c.description,
      leaderAddress: c.leaderAddress,
      memberCount: members.length,
      maxMembers: c.maxMembers || 50,
      totalWins: c.totalWins || 0,
      totalLosses: c.totalLosses || 0,
      trophies: c.trophies || 0,
      createdAt: c.createdAt,
    });
  });

  clans.sort((a, b) => (b.trophies as number) - (a.trophies as number));

  const total = clans.length;
  const start = (page - 1) * limit;

  res.json({
    clans: clans.slice(start, start + limit),
    total,
    page,
    limit,
  });
});

/** GET /api/clan/:id — Get clan details. */
router.get("/:id", async (req, res) => {
  const snap = await clansRef.child(req.params.id).once("value");

  if (!snap.exists()) {
    res.status(404).json({ error: "Clan not found" });
    return;
  }

  const clan = snap.val();
  const membersObj = clan.members || {};
  const memberAddresses = Object.keys(membersObj);

  const members = await Promise.all(
    memberAddresses.map(async (addr) => {
      const user = await getUser(addr);
      return {
        address: addr,
        gamerTag: user?.gamerTag || addr.slice(0, 8),
        role: membersObj[addr].role,
        wins: user?.wins || 0,
        losses: user?.losses || 0,
        joinedAt: membersObj[addr].joinedAt,
      };
    })
  );

  res.json({
    id: req.params.id,
    name: clan.name,
    tag: clan.tag,
    description: clan.description,
    leaderAddress: clan.leaderAddress,
    memberCount: members.length,
    maxMembers: clan.maxMembers || 50,
    totalWins: clan.totalWins || 0,
    totalLosses: clan.totalLosses || 0,
    trophies: clan.trophies || 0,
    createdAt: clan.createdAt,
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

  // Check if user is already in a clan.
  const allClans = await clansRef.once("value");
  let alreadyInClan = false;

  if (allClans.exists()) {
    allClans.forEach((child) => {
      const c = child.val();
      if (c.members && c.members[req.userAddress!]) {
        alreadyInClan = true;
      }
    });
  }

  if (alreadyInClan) {
    res.status(409).json({ error: "Already in a clan" });
    return;
  }

  const ref = clansRef.push();
  await ref.set({
    name,
    tag: tag.toUpperCase(),
    description: description || null,
    leaderAddress: req.userAddress!,
    maxMembers: 50,
    totalWins: 0,
    totalLosses: 0,
    trophies: 0,
    createdAt: Date.now(),
    members: {
      [req.userAddress!]: {
        role: "LEADER",
        joinedAt: Date.now(),
      },
    },
  });

  res.json({ id: ref.key, name, tag: tag.toUpperCase() });
});

/** POST /api/clan/:id/join — Join a clan. */
router.post("/:id/join", requireAuth, async (req: AuthRequest, res) => {
  // Check if already in a clan.
  const allClans = await clansRef.once("value");
  let alreadyInClan = false;

  if (allClans.exists()) {
    allClans.forEach((child) => {
      const c = child.val();
      if (c.members && c.members[req.userAddress!]) {
        alreadyInClan = true;
      }
    });
  }

  if (alreadyInClan) {
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

  res.json({ status: "left" });
});

export default router;
