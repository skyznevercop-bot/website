import { Router } from "express";
import { PrismaClient } from "@prisma/client";
import { AuthRequest, requireAuth } from "../middleware/auth";

const router = Router();
const prisma = new PrismaClient();

/** GET /api/clan — List all clans. */
router.get("/", async (req, res) => {
  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
  const skip = (page - 1) * limit;

  const [clans, total] = await Promise.all([
    prisma.clan.findMany({
      include: { members: { select: { id: true } } },
      orderBy: { trophies: "desc" },
      skip,
      take: limit,
    }),
    prisma.clan.count(),
  ]);

  const result = clans.map((c) => ({
    id: c.id,
    name: c.name,
    tag: c.tag,
    description: c.description,
    leaderAddress: c.leaderAddress,
    memberCount: c.members.length,
    maxMembers: c.maxMembers,
    totalWins: c.totalWins,
    totalLosses: c.totalLosses,
    trophies: c.trophies,
    createdAt: c.createdAt,
  }));

  res.json({ clans: result, total, page, limit });
});

/** GET /api/clan/:id — Get clan details. */
router.get("/:id", async (req, res) => {
  const clan = await prisma.clan.findUnique({
    where: { id: req.params.id },
    include: {
      members: {
        include: {
          user: {
            select: {
              walletAddress: true,
              gamerTag: true,
              eloRating: true,
              wins: true,
              losses: true,
            },
          },
        },
        orderBy: { role: "asc" },
      },
    },
  });

  if (!clan) {
    res.status(404).json({ error: "Clan not found" });
    return;
  }

  res.json({
    ...clan,
    memberCount: clan.members.length,
    members: clan.members.map((m) => ({
      address: m.userAddress,
      gamerTag: m.user.gamerTag || m.userAddress.slice(0, 8),
      role: m.role,
      elo: m.user.eloRating,
      wins: m.user.wins,
      losses: m.user.losses,
      donations: m.donations,
      joinedAt: m.joinedAt,
    })),
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
  const existingMember = await prisma.clanMember.findUnique({
    where: { userAddress: req.userAddress! },
  });

  if (existingMember) {
    res.status(409).json({ error: "Already in a clan" });
    return;
  }

  try {
    const clan = await prisma.clan.create({
      data: {
        name,
        tag: tag.toUpperCase(),
        description: description || null,
        leaderAddress: req.userAddress!,
        members: {
          create: {
            userAddress: req.userAddress!,
            role: "LEADER",
          },
        },
      },
    });

    res.json(clan);
  } catch {
    res.status(409).json({ error: "Clan name or tag already taken" });
  }
});

/** POST /api/clan/:id/join — Join a clan. */
router.post("/:id/join", requireAuth, async (req: AuthRequest, res) => {
  // Check if already in a clan.
  const existing = await prisma.clanMember.findUnique({
    where: { userAddress: req.userAddress! },
  });

  if (existing) {
    res.status(409).json({ error: "Already in a clan" });
    return;
  }

  const clan = await prisma.clan.findUnique({
    where: { id: req.params.id },
    include: { members: { select: { id: true } } },
  });

  if (!clan) {
    res.status(404).json({ error: "Clan not found" });
    return;
  }

  if (clan.members.length >= clan.maxMembers) {
    res.status(400).json({ error: "Clan is full" });
    return;
  }

  await prisma.clanMember.create({
    data: {
      clanId: clan.id,
      userAddress: req.userAddress!,
      role: "MEMBER",
    },
  });

  res.json({ status: "joined", clanId: clan.id });
});

/** DELETE /api/clan/:id/leave — Leave a clan. */
router.delete("/:id/leave", requireAuth, async (req: AuthRequest, res) => {
  const member = await prisma.clanMember.findUnique({
    where: { userAddress: req.userAddress! },
  });

  if (!member || member.clanId !== req.params.id) {
    res.status(404).json({ error: "Not in this clan" });
    return;
  }

  if (member.role === "LEADER") {
    // Transfer leadership or dissolve clan.
    const otherMembers = await prisma.clanMember.findMany({
      where: { clanId: req.params.id, NOT: { userAddress: req.userAddress! } },
      orderBy: { role: "asc" },
    });

    if (otherMembers.length > 0) {
      // Transfer to next highest role.
      await prisma.clanMember.update({
        where: { id: otherMembers[0].id },
        data: { role: "LEADER" },
      });
      await prisma.clan.update({
        where: { id: req.params.id },
        data: { leaderAddress: otherMembers[0].userAddress },
      });
    } else {
      // Dissolve clan.
      await prisma.clan.delete({ where: { id: req.params.id } });
      await prisma.clanMember.delete({
        where: { userAddress: req.userAddress! },
      });
      res.json({ status: "clan_dissolved" });
      return;
    }
  }

  await prisma.clanMember.delete({
    where: { userAddress: req.userAddress! },
  });

  res.json({ status: "left" });
});

export default router;
