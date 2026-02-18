import {
  getMatchesByStatus,
  updateMatch,
  DbMatch,
} from "./firebase";
import {
  startGameOnChain,
  endGameOnChain,
  fetchGameAccount,
  GameStatus,
} from "../utils/solana";

/**
 * Background on-chain recorder — creates and settles game records on Solana
 * in batches for auditability. Users NEVER wait for this.
 *
 * This is purely an audit trail. The platform balance system handles
 * real-time payouts. On-chain records provide transparency and dispute resolution.
 *
 * Runs every 60 seconds, processes up to 5 matches per cycle.
 */
export function startOnChainRecorderLoop(): void {
  setInterval(async () => {
    try {
      await recordCompletedMatches();
    } catch (err) {
      console.error("[OnChainRecorder] Error:", err);
    }
  }, 60_000);

  console.log("[OnChainRecorder] Started — recording matches on-chain every 60s");
}

/**
 * Find completed matches not yet recorded on-chain and record them.
 * Two-phase: first create the game, then settle it.
 */
async function recordCompletedMatches(): Promise<void> {
  const BATCH_SIZE = 5;

  for (const status of ["completed", "tied", "forfeited"] as const) {
    const matches = await getMatchesByStatus(status);

    let processed = 0;
    for (const { id, data: match } of matches) {
      if (processed >= BATCH_SIZE) break;

      // Skip matches already recorded on-chain.
      if (match.onChainRecorded) continue;

      // Skip matches that have been retried too many times.
      const retries = match.onChainRecorderRetries ?? 0;
      if (retries >= 5) continue;

      try {
        await recordMatchOnChain(id, match);
        await updateMatch(id, { onChainRecorded: true });
        processed++;
        console.log(`[OnChainRecorder] Recorded match ${id} on-chain`);
      } catch (err) {
        await updateMatch(id, { onChainRecorderRetries: retries + 1 });
        console.error(
          `[OnChainRecorder] Failed to record match ${id} (attempt ${retries + 1}):`,
          err
        );
      }
    }
  }
}

/**
 * Record a single match on-chain: create game + immediately settle it.
 * This is a two-instruction flow done in sequence (not a single TX because
 * start_game and end_game have different account sets).
 */
async function recordMatchOnChain(
  matchId: string,
  match: DbMatch
): Promise<void> {
  // If the match doesn't have an on-chain game ID yet, create one.
  let gameId = match.onChainGameId;

  if (!gameId) {
    const durationSeconds = parseDurationToSeconds(match.duration);
    gameId = await startGameOnChain(
      match.player1,
      match.player2,
      match.betAmount,
      durationSeconds
    );
    await updateMatch(matchId, { onChainGameId: gameId });
  }

  // Check if the game is already settled on-chain.
  const game = await fetchGameAccount(BigInt(gameId));
  if (game && game.status !== GameStatus.Pending && game.status !== GameStatus.Active) {
    // Already settled on-chain — just mark it.
    return;
  }

  // Settle on-chain.
  const isForfeit = match.status === "forfeited";
  const isTie = match.status === "tied";

  const p1PnlBps = Math.round((match.player1Roi ?? 0) * 10000);
  const p2PnlBps = Math.round((match.player2Roi ?? 0) * 10000);

  await endGameOnChain(
    gameId,
    isTie ? null : (match.winner ?? null),
    p1PnlBps,
    p2PnlBps,
    isForfeit
  );
}

function parseDurationToSeconds(duration: string): number {
  const m = duration.match(/^(\d+)(m|h)$/);
  if (!m) return 15 * 60;
  const value = parseInt(m[1]);
  const unit = m[2];
  if (unit === "h") return value * 60 * 60;
  return value * 60;
}
