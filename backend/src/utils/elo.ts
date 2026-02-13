/**
 * Classic ELO calculation with dynamic K-factor.
 * K = 40 for players with < 30 games, 32 otherwise.
 */
export function calculateElo(
  winnerElo: number,
  loserElo: number,
  winnerGames: number,
  loserGames: number
): { newWinnerElo: number; newLoserElo: number } {
  const kWinner = winnerGames < 30 ? 40 : 32;
  const kLoser = loserGames < 30 ? 40 : 32;

  const expectedWinner =
    1 / (1 + Math.pow(10, (loserElo - winnerElo) / 400));
  const expectedLoser = 1 - expectedWinner;

  const newWinnerElo = Math.round(winnerElo + kWinner * (1 - expectedWinner));
  const newLoserElo = Math.max(
    100,
    Math.round(loserElo + kLoser * (0 - expectedLoser))
  );

  return { newWinnerElo, newLoserElo };
}
