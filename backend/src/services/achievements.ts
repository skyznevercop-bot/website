import { DbUser, usersRef } from "./firebase";
import { broadcastToUser } from "../ws/rooms";

// ── Achievement Definitions ──────────────────────────────────────

export interface AchievementDef {
  id: string;
  name: string;
  description: string;
  icon: string;
  category: "wins" | "streaks" | "pnl" | "trades" | "special";
  check: (stats: AchievementStats, ctx?: MatchContext) => boolean;
}

export interface AchievementStats {
  wins: number;
  losses: number;
  ties: number;
  totalPnl: number;
  currentStreak: number;
  bestStreak: number;
  gamesPlayed: number;
  totalTrades: number;
}

export interface MatchContext {
  isWinner: boolean;
  tradeWinRate?: number; // 0-100
  totalTradesInMatch?: number;
}

export const ACHIEVEMENTS: AchievementDef[] = [
  // ── Win Milestones ───────────────────────────────────
  {
    id: "first_blood",
    name: "First Blood",
    description: "Win your first match",
    icon: "sword",
    category: "wins",
    check: (s) => s.wins >= 1,
  },
  {
    id: "rising_star",
    name: "Rising Star",
    description: "Win 5 matches",
    icon: "star",
    category: "wins",
    check: (s) => s.wins >= 5,
  },
  {
    id: "arena_veteran",
    name: "Arena Veteran",
    description: "Win 10 matches",
    icon: "shield",
    category: "wins",
    check: (s) => s.wins >= 10,
  },
  {
    id: "gladiator",
    name: "Gladiator",
    description: "Win 25 matches",
    icon: "trophy",
    category: "wins",
    check: (s) => s.wins >= 25,
  },
  {
    id: "war_machine",
    name: "War Machine",
    description: "Win 50 matches",
    icon: "rocket",
    category: "wins",
    check: (s) => s.wins >= 50,
  },
  {
    id: "legend",
    name: "Legend",
    description: "Win 100 matches",
    icon: "crown",
    category: "wins",
    check: (s) => s.wins >= 100,
  },

  // ── Streak Milestones ────────────────────────────────
  {
    id: "hot_hand",
    name: "Hot Hand",
    description: "Achieve a 3-win streak",
    icon: "fire",
    category: "streaks",
    check: (s) => s.bestStreak >= 3,
  },
  {
    id: "on_fire",
    name: "On Fire",
    description: "Achieve a 5-win streak",
    icon: "flame",
    category: "streaks",
    check: (s) => s.bestStreak >= 5,
  },
  {
    id: "unstoppable",
    name: "Unstoppable",
    description: "Achieve a 10-win streak",
    icon: "bolt",
    category: "streaks",
    check: (s) => s.bestStreak >= 10,
  },

  // ── PnL Milestones ──────────────────────────────────
  {
    id: "money_maker",
    name: "Money Maker",
    description: "Earn $1,000 cumulative PnL",
    icon: "dollar",
    category: "pnl",
    check: (s) => s.totalPnl >= 1000,
  },
  {
    id: "big_earner",
    name: "Big Earner",
    description: "Earn $10,000 cumulative PnL",
    icon: "money_bag",
    category: "pnl",
    check: (s) => s.totalPnl >= 10000,
  },
  {
    id: "whale",
    name: "Whale",
    description: "Earn $100,000 cumulative PnL",
    icon: "whale",
    category: "pnl",
    check: (s) => s.totalPnl >= 100000,
  },
  {
    id: "moon_walker",
    name: "Moon Walker",
    description: "Earn $1,000,000 cumulative PnL",
    icon: "moon",
    category: "pnl",
    check: (s) => s.totalPnl >= 1000000,
  },

  // ── Trade Volume ────────────────────────────────────
  {
    id: "trader",
    name: "Trader",
    description: "Place 100 total trades",
    icon: "chart",
    category: "trades",
    check: (s) => s.totalTrades >= 100,
  },
  {
    id: "active_trader",
    name: "Active Trader",
    description: "Place 500 total trades",
    icon: "chart_up",
    category: "trades",
    check: (s) => s.totalTrades >= 500,
  },
  {
    id: "market_mover",
    name: "Market Mover",
    description: "Place 1,000 total trades",
    icon: "trending",
    category: "trades",
    check: (s) => s.totalTrades >= 1000,
  },

  // ── Special ─────────────────────────────────────────
  {
    id: "baptism",
    name: "Baptism",
    description: "Complete your first match",
    icon: "play",
    category: "special",
    check: (s) => s.gamesPlayed >= 1,
  },
  {
    id: "flawless_victory",
    name: "Flawless Victory",
    description: "Win a match with 100% trade win rate",
    icon: "diamond",
    category: "special",
    check: (s, ctx) =>
      !!ctx &&
      ctx.isWinner &&
      (ctx.totalTradesInMatch ?? 0) > 0 &&
      ctx.tradeWinRate === 100,
  },
];

/**
 * Check all achievements against the player's updated stats and award any
 * newly unlocked ones. Returns the list of newly unlocked achievement IDs.
 */
export async function checkAndAwardAchievements(
  address: string,
  stats: AchievementStats,
  existingAchievements: Record<string, boolean>,
  matchContext?: MatchContext
): Promise<string[]> {
  const newlyUnlocked: string[] = [];

  for (const achievement of ACHIEVEMENTS) {
    // Skip if already unlocked
    if (existingAchievements[achievement.id]) continue;

    // Check condition
    if (achievement.check(stats, matchContext)) {
      newlyUnlocked.push(achievement.id);
    }
  }

  if (newlyUnlocked.length === 0) return [];

  // Write all newly unlocked achievements to Firebase in one update
  const updates: Record<string, boolean> = {};
  for (const id of newlyUnlocked) {
    updates[`achievements/${id}`] = true;
  }
  await usersRef.child(address).update(updates);

  // Notify the player via WebSocket
  const unlockedDetails = newlyUnlocked.map((id) => {
    const def = ACHIEVEMENTS.find((a) => a.id === id)!;
    return { id: def.id, name: def.name, description: def.description, icon: def.icon };
  });

  broadcastToUser(address, {
    type: "achievement_unlocked",
    achievements: unlockedDetails,
  });

  console.log(
    `[Achievements] ${address.slice(0, 8)}… unlocked: ${newlyUnlocked.join(", ")}`
  );

  return newlyUnlocked;
}
