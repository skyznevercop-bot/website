import { Router } from "express";
import { config } from "../config";
import {
  getUser,
  getPositions,
  matchesRef,
} from "../services/firebase";
import { ACHIEVEMENTS } from "../services/achievements";

const router = Router();

/** GET /api/profile/:address — Full player profile with deep stats. */
router.get("/:address", async (req, res) => {
  const { address } = req.params;

  try {
    const user = await getUser(address);
    if (!user) {
      return res.status(404).json({ error: "Player not found" });
    }

    const gamesPlayed = user.gamesPlayed || 0;
    const wins = user.wins || 0;
    const winRate = gamesPlayed > 0 ? Math.round((wins / gamesPlayed) * 1000) / 10 : 0;

    // ── Fetch match history (last 100 for deep stats, return last 20) ──
    const [snap1, snap2] = await Promise.all([
      matchesRef.orderByChild("player1").equalTo(address).once("value"),
      matchesRef.orderByChild("player2").equalTo(address).once("value"),
    ]);

    const rawMatches: Array<Record<string, unknown> & { id: string }> = [];
    const seen = new Set<string>();
    const settledStatuses = new Set(["completed", "tied", "forfeited"]);

    for (const snap of [snap1, snap2]) {
      if (snap.exists()) {
        snap.forEach((child) => {
          const m = child.val();
          if (!seen.has(child.key!) && settledStatuses.has(m.status)) {
            seen.add(child.key!);
            rawMatches.push({ id: child.key!, ...m });
          }
        });
      }
    }

    rawMatches.sort(
      (a, b) => ((b.settledAt as number) || 0) - ((a.settledAt as number) || 0)
    );

    // ── Deep stats from last 100 matches ──
    const statsMatches = rawMatches.slice(0, 100);
    const rake = config.rakePercent;

    let bestMatchPnl = 0;
    let worstMatchPnl = 0;
    let totalMatchPnl = 0;
    const assetCounts: Record<string, number> = {};
    let totalLeverage = 0;
    let totalVolume = 0;
    let leverageCount = 0;

    // Fetch positions for stats matches (batch in groups of 20 for perf)
    for (let i = 0; i < statsMatches.length; i += 20) {
      const batch = statsMatches.slice(i, i + 20);
      const batchPositions = await Promise.all(
        batch.map((m) => getPositions(m.id, address))
      );

      for (let j = 0; j < batch.length; j++) {
        const m = batch[j];
        const positions = batchPositions[j];
        const betAmount = (m.betAmount as number) || 0;

        // Match PnL (betting PnL, not demo PnL)
        let matchPnl: number;
        if (m.status === "tied") {
          matchPnl = 0;
        } else if (m.winner === address) {
          matchPnl = betAmount * (1 - rake);
        } else {
          matchPnl = -betAmount;
        }
        totalMatchPnl += matchPnl;
        if (matchPnl > bestMatchPnl) bestMatchPnl = matchPnl;
        if (matchPnl < worstMatchPnl) worstMatchPnl = matchPnl;

        // Position-level stats
        for (const pos of positions) {
          assetCounts[pos.assetSymbol] = (assetCounts[pos.assetSymbol] || 0) + 1;
          totalLeverage += pos.leverage;
          totalVolume += pos.size;
          leverageCount++;
        }
      }
    }

    const avgPnlPerMatch =
      statsMatches.length > 0
        ? Math.round((totalMatchPnl / statsMatches.length) * 100) / 100
        : 0;

    const favoriteAsset =
      Object.keys(assetCounts).length > 0
        ? Object.entries(assetCounts).sort((a, b) => b[1] - a[1])[0][0]
        : null;

    const avgLeverage =
      leverageCount > 0
        ? Math.round((totalLeverage / leverageCount) * 10) / 10
        : 0;

    // ── Enrich last 20 matches for display ──
    const recentMatches = rawMatches.slice(0, 20);
    const opponentAddresses = recentMatches.map((m) =>
      m.player1 === address ? (m.player2 as string) : (m.player1 as string)
    );
    const uniqueOpponents = [...new Set(opponentAddresses)];
    const opponentUsers = await Promise.all(
      uniqueOpponents.map((a) => getUser(a))
    );
    const tagMap = new Map<string, string>();
    uniqueOpponents.forEach((a, i) => {
      tagMap.set(a, opponentUsers[i]?.gamerTag || a.slice(0, 8));
    });

    const enrichedMatches = recentMatches.map((m) => {
      const oppAddr =
        m.player1 === address ? (m.player2 as string) : (m.player1 as string);
      const betAmount = (m.betAmount as number) || 0;

      let result: "WIN" | "LOSS" | "TIE";
      let pnl: number;

      if (m.status === "tied") {
        result = "TIE";
        pnl = 0;
      } else if (m.winner === address) {
        result = "WIN";
        pnl = betAmount * (1 - rake);
      } else {
        result = "LOSS";
        pnl = -betAmount;
      }

      return {
        id: m.id,
        opponentAddress: oppAddr,
        opponentGamerTag: tagMap.get(oppAddr) || oppAddr.slice(0, 8),
        duration: m.duration as string,
        betAmount,
        result,
        pnl,
        settledAt: m.settledAt as number,
      };
    });

    res.json({
      walletAddress: address,
      gamerTag: user.gamerTag || address.slice(0, 8),
      wins,
      losses: user.losses || 0,
      ties: user.ties || 0,
      totalPnl: user.totalPnl || 0,
      currentStreak: user.currentStreak || 0,
      bestStreak: user.bestStreak || 0,
      gamesPlayed,
      totalTrades: user.totalTrades || 0,
      winRate,
      achievements: user.achievements || {},
      createdAt: user.createdAt || 0,
      deepStats: {
        avgPnlPerMatch,
        bestMatchPnl,
        worstMatchPnl,
        favoriteAsset,
        avgLeverage,
        totalVolume: Math.round(totalVolume * 100) / 100,
      },
      recentMatches: enrichedMatches,
    });
  } catch (err) {
    console.error("[Profile] Error:", err);
    res.status(500).json({ error: "Failed to load profile" });
  }
});

/** GET /api/profile/:address/achievements — Full achievement catalog with unlock status. */
router.get("/:address/achievements", async (req, res) => {
  const { address } = req.params;

  try {
    const user = await getUser(address);
    const userAchievements = user?.achievements || {};

    const catalog = ACHIEVEMENTS.map((a) => ({
      id: a.id,
      name: a.name,
      description: a.description,
      icon: a.icon,
      category: a.category,
      unlocked: !!userAchievements[a.id],
    }));

    const unlockedCount = catalog.filter((a) => a.unlocked).length;

    res.json({
      achievements: catalog,
      unlockedCount,
      totalCount: ACHIEVEMENTS.length,
    });
  } catch (err) {
    console.error("[Profile] Achievements error:", err);
    res.status(500).json({ error: "Failed to load achievements" });
  }
});

export default router;
