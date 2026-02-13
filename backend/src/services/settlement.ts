import { PrismaClient } from "@prisma/client";
import { calculateElo } from "../utils/elo";
import { getLatestPrices } from "./price-oracle";
import { broadcastToMatch } from "../ws/rooms";

const prisma = new PrismaClient();

/**
 * Start the settlement loop — checks every 5 seconds for matches
 * past their end time that need to be settled.
 */
export function startSettlementLoop(): void {
  setInterval(async () => {
    try {
      const now = new Date();

      // Find active matches past their end time.
      const expiredMatches = await prisma.match.findMany({
        where: {
          status: "ACTIVE",
          endTime: { lte: now },
        },
        include: {
          positions: true,
        },
      });

      for (const match of expiredMatches) {
        await settleMatch(match);
      }
    } catch (err) {
      console.error("[Settlement] Error:", err);
    }
  }, 5000);

  console.log("[Settlement] Started — checking every 5s");
}

/**
 * Settle a single match: calculate PnL, determine winner, update stats.
 */
async function settleMatch(
  match: Awaited<ReturnType<typeof prisma.match.findFirst>> & {
    positions: Array<{
      id: string;
      playerAddress: string;
      assetSymbol: string;
      isLong: boolean;
      entryPrice: number;
      exitPrice: number | null;
      size: number;
      leverage: number;
      pnl: number | null;
      closedAt: Date | null;
    }>;
  }
): Promise<void> {
  if (!match) return;

  const prices = getLatestPrices();
  const priceMap: Record<string, number> = {
    BTC: prices.btc,
    ETH: prices.eth,
    SOL: prices.sol,
  };

  // Close any open positions at current prices.
  const openPositions = match.positions.filter((p) => !p.closedAt);
  for (const pos of openPositions) {
    const currentPrice = priceMap[pos.assetSymbol] || pos.entryPrice;
    const priceDiff = pos.isLong
      ? currentPrice - pos.entryPrice
      : pos.entryPrice - currentPrice;
    const pnl = (priceDiff / pos.entryPrice) * pos.size * pos.leverage;

    await prisma.position.update({
      where: { id: pos.id },
      data: {
        exitPrice: currentPrice,
        pnl,
        closedAt: new Date(),
        closeReason: "match_end",
      },
    });
  }

  // Calculate total PnL for each player.
  const allPositions = await prisma.position.findMany({
    where: { matchId: match.id },
  });

  const p1Pnl = allPositions
    .filter((p) => p.playerAddress === match.player1Address)
    .reduce((sum, p) => sum + (p.pnl || 0), 0);

  const p2Pnl = allPositions
    .filter((p) => p.playerAddress === match.player2Address)
    .reduce((sum, p) => sum + (p.pnl || 0), 0);

  // Determine winner (higher PnL wins; tie goes to player 1).
  const winnerAddress =
    p1Pnl >= p2Pnl ? match.player1Address : match.player2Address;
  const loserAddress =
    winnerAddress === match.player1Address
      ? match.player2Address
      : match.player1Address;

  // Fetch player profiles for ELO.
  const [winner, loser] = await Promise.all([
    prisma.user.findUnique({ where: { walletAddress: winnerAddress } }),
    prisma.user.findUnique({ where: { walletAddress: loserAddress } }),
  ]);

  if (!winner || !loser) return;

  const { newWinnerElo, newLoserElo } = calculateElo(
    winner.eloRating,
    loser.eloRating,
    winner.wins + winner.losses,
    loser.wins + loser.losses
  );

  // Update match.
  await prisma.match.update({
    where: { id: match.id },
    data: {
      status: "COMPLETED",
      winnerAddress,
      player1Pnl: p1Pnl,
      player2Pnl: p2Pnl,
      settledAt: new Date(),
    },
  });

  // Update winner stats.
  await prisma.user.update({
    where: { walletAddress: winnerAddress },
    data: {
      eloRating: newWinnerElo,
      wins: { increment: 1 },
      totalPnl: { increment: match.betAmount },
      currentStreak: { increment: 1 },
    },
  });

  // Update loser stats.
  await prisma.user.update({
    where: { walletAddress: loserAddress },
    data: {
      eloRating: newLoserElo,
      losses: { increment: 1 },
      totalPnl: { decrement: match.betAmount },
      currentStreak: 0,
    },
  });

  // Broadcast match end to both players.
  broadcastToMatch(match.id, {
    type: "match_end",
    matchId: match.id,
    winner: winnerAddress,
    p1Pnl,
    p2Pnl,
    eloChange: {
      [winnerAddress]: newWinnerElo - winner.eloRating,
      [loserAddress]: newLoserElo - loser.eloRating,
    },
  });

  console.log(
    `[Settlement] Match ${match.id} settled | Winner: ${winnerAddress} | PnL: ${p1Pnl.toFixed(2)} vs ${p2Pnl.toFixed(2)}`
  );

  // TODO: Call Anchor end_game instruction for on-chain settlement.
  // TODO: Notify winner they can call claim_winnings.
}
