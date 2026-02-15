import { Server as HttpServer } from "http";
import WebSocket, { WebSocketServer } from "ws";
import jwt from "jsonwebtoken";
import { config } from "../config";
import {
  joinMatchRoom,
  leaveMatchRoom,
  registerUserConnection,
  unregisterUserConnection,
  broadcastToUser,
  broadcastToMatch,
  isUserConnected,
  getActiveMatchIds,
} from "./rooms";
import { joinQueue, leaveQueue } from "../services/matchmaking";
import { getLatestPrices } from "../services/price-oracle";
import {
  createPosition,
  getPositions,
  updatePosition,
  getMatch,
  DbPosition,
} from "../services/firebase";
import { settleByForfeit } from "../services/settlement";

const DEMO_BALANCE = config.demoInitialBalance;
const FORFEIT_GRACE_MS = 30_000; // 30 seconds

interface AuthenticatedSocket extends WebSocket {
  userAddress?: string;
  currentMatchId?: string;
}

/** Active forfeit timers: matchId_playerAddress → timeout handle. */
const forfeitTimers = new Map<string, ReturnType<typeof setTimeout>>();

export { broadcastToUser };

export function setupWebSocket(server: HttpServer): void {
  const wss = new WebSocketServer({ server, path: "/ws" });

  wss.on("connection", (ws: AuthenticatedSocket, req) => {
    // Authenticate via query param token.
    const url = new URL(req.url || "/", `http://${req.headers.host}`);
    const token = url.searchParams.get("token");

    if (!token) {
      ws.close(4001, "Missing authentication token");
      return;
    }

    try {
      const payload = jwt.verify(token, config.jwtSecret) as {
        address: string;
      };
      ws.userAddress = payload.address;
      registerUserConnection(payload.address, ws);

      // Cancel any pending forfeit timer for this player.
      cancelForfeitTimersForPlayer(payload.address);
    } catch {
      ws.close(4001, "Invalid authentication token");
      return;
    }

    console.log(`[WS] Client connected: ${ws.userAddress}`);

    ws.on("message", async (raw) => {
      try {
        const data = JSON.parse(raw.toString());
        await handleMessage(ws, data);
      } catch (err) {
        ws.send(
          JSON.stringify({ type: "error", message: "Invalid message format" })
        );
      }
    });

    ws.on("close", () => {
      if (ws.userAddress) {
        unregisterUserConnection(ws.userAddress, ws);

        if (ws.currentMatchId) {
          leaveMatchRoom(ws.currentMatchId, ws);

          // Start 30s forfeit timer if player has no other connections.
          if (!isUserConnected(ws.userAddress)) {
            startForfeitTimer(ws.currentMatchId, ws.userAddress);
          }
        }
      }
      console.log(`[WS] Client disconnected: ${ws.userAddress}`);
    });
  });

  // Broadcast opponent updates for all active matches every 3 seconds.
  setInterval(async () => {
    const matchIds = getActiveMatchIds();
    for (const matchId of matchIds) {
      const match = await getMatch(matchId);
      if (!match || match.status !== "active") continue;
      broadcastOpponentUpdate(matchId, match.player1).catch(() => {});
      broadcastOpponentUpdate(matchId, match.player2).catch(() => {});
    }
  }, 3000);

  console.log("[WS] WebSocket server started on /ws");
}

/**
 * Start a 30-second forfeit timer for a disconnected player.
 * If they don't reconnect within the grace period, the match is forfeited.
 */
function startForfeitTimer(matchId: string, playerAddress: string): void {
  const key = `${matchId}_${playerAddress}`;

  // Don't start duplicate timers.
  if (forfeitTimers.has(key)) return;

  console.log(
    `[WS] Disconnect detected: ${playerAddress} in match ${matchId} — 30s grace period started`
  );

  // Notify the opponent.
  broadcastToMatch(matchId, {
    type: "opponent_disconnected",
    player: playerAddress,
    graceSeconds: 30,
  });

  const timer = setTimeout(async () => {
    forfeitTimers.delete(key);

    // Check if player reconnected during the grace period.
    if (isUserConnected(playerAddress)) {
      console.log(
        `[WS] Player ${playerAddress} reconnected — forfeit cancelled`
      );
      return;
    }

    console.log(
      `[WS] Forfeit triggered: ${playerAddress} in match ${matchId}`
    );

    await settleByForfeit(matchId, playerAddress);
  }, FORFEIT_GRACE_MS);

  forfeitTimers.set(key, timer);
}

/**
 * Cancel all forfeit timers for a player (e.g., on reconnect).
 */
function cancelForfeitTimersForPlayer(playerAddress: string): void {
  for (const [key, timer] of forfeitTimers) {
    if (key.endsWith(`_${playerAddress}`)) {
      clearTimeout(timer);
      forfeitTimers.delete(key);

      const matchId = key.split("_").slice(0, -1).join("_");
      console.log(
        `[WS] Forfeit timer cancelled for ${playerAddress} in match ${matchId}`
      );

      // Notify the match that the player reconnected.
      broadcastToMatch(matchId, {
        type: "opponent_reconnected",
        player: playerAddress,
      });
    }
  }
}

async function handleMessage(
  ws: AuthenticatedSocket,
  data: Record<string, unknown>
): Promise<void> {
  if (!ws.userAddress) return;

  switch (data.type) {
    case "join_queue": {
      const { duration, bet } = data as {
        duration: string;
        bet: number;
      };
      await joinQueue(ws.userAddress, duration, bet);
      ws.send(JSON.stringify({ type: "queue_joined", duration, bet }));
      break;
    }

    case "leave_queue": {
      const { duration, bet } = data as {
        duration: string;
        bet: number;
      };
      await leaveQueue(ws.userAddress, duration, bet);
      ws.send(JSON.stringify({ type: "queue_left" }));
      break;
    }

    case "join_match": {
      const { matchId } = data as { matchId: string };
      if (ws.currentMatchId) {
        leaveMatchRoom(ws.currentMatchId, ws);
      }
      ws.currentMatchId = matchId;
      joinMatchRoom(matchId, ws);

      // Cancel any pending forfeit timer for this player/match.
      cancelForfeitTimersForPlayer(ws.userAddress);

      // Send current prices immediately.
      ws.send(
        JSON.stringify({ type: "price_update", ...getLatestPrices() })
      );
      break;
    }

    case "open_position": {
      const { matchId, asset, isLong, size, leverage } = data as {
        matchId: string;
        asset: string;
        isLong: boolean;
        size: number;
        leverage: number;
      };

      // Input validation.
      if (typeof size !== "number" || size < 1 || size > DEMO_BALANCE) {
        ws.send(
          JSON.stringify({ type: "error", message: "Invalid position size (1 – $1M)" })
        );
        return;
      }
      if (typeof leverage !== "number" || leverage < 1 || leverage > 100) {
        ws.send(
          JSON.stringify({ type: "error", message: "Invalid leverage (1x – 100x)" })
        );
        return;
      }
      const validAssets = ["BTC", "ETH", "SOL"];
      if (!validAssets.includes(asset)) {
        ws.send(
          JSON.stringify({ type: "error", message: "Unknown asset" })
        );
        return;
      }

      const prices = getLatestPrices();
      const priceMap: Record<string, number> = {
        BTC: prices.btc,
        ETH: prices.eth,
        SOL: prices.sol,
      };
      const entryPrice = priceMap[asset];
      if (!entryPrice) {
        ws.send(
          JSON.stringify({ type: "error", message: "Price unavailable" })
        );
        return;
      }

      const positionId = await createPosition(matchId, {
        playerAddress: ws.userAddress,
        assetSymbol: asset,
        isLong,
        entryPrice,
        size,
        leverage,
        openedAt: Date.now(),
      });

      ws.send(
        JSON.stringify({
          type: "position_opened",
          position: {
            id: positionId,
            asset,
            isLong,
            entryPrice,
            size,
            leverage,
          },
        })
      );

      // Notify opponent of position count change.
      broadcastOpponentUpdate(matchId, ws.userAddress);
      break;
    }

    case "close_position": {
      const { matchId, positionId } = data as {
        matchId: string;
        positionId: string;
      };

      const positions = await getPositions(matchId, ws.userAddress);
      const position = positions.find(
        (p) => p.id === positionId && !p.closedAt
      );

      if (!position) {
        ws.send(
          JSON.stringify({ type: "error", message: "Position not found" })
        );
        return;
      }

      const prices = getLatestPrices();
      const priceMap: Record<string, number> = {
        BTC: prices.btc,
        ETH: prices.eth,
        SOL: prices.sol,
      };
      const exitPrice =
        priceMap[position.assetSymbol] || position.entryPrice;
      const priceDiff = position.isLong
        ? exitPrice - position.entryPrice
        : position.entryPrice - exitPrice;
      const pnl =
        (priceDiff / position.entryPrice) * position.size * position.leverage;

      await updatePosition(matchId, positionId, {
        exitPrice,
        pnl,
        closedAt: Date.now(),
        closeReason: "manual",
      });

      ws.send(
        JSON.stringify({
          type: "position_closed",
          positionId,
          exitPrice,
          pnl,
        })
      );

      broadcastOpponentUpdate(matchId, ws.userAddress);
      break;
    }

    case "chat_message": {
      const { matchId, content, senderTag } = data as {
        matchId: string;
        content: string;
        senderTag: string;
      };

      if (
        !matchId ||
        !content ||
        typeof content !== "string" ||
        content.length > 200
      ) {
        break;
      }

      // Broadcast to the match room so the opponent receives it.
      broadcastToMatch(matchId, {
        type: "chat_message",
        matchId,
        senderTag: senderTag || ws.userAddress,
        content,
        sender: ws.userAddress,
        timestamp: Date.now(),
      });
      break;
    }

    default:
      ws.send(
        JSON.stringify({ type: "error", message: "Unknown event type" })
      );
  }
}

/**
 * Calculate and broadcast opponent update to the match room.
 */
async function broadcastOpponentUpdate(
  matchId: string,
  playerAddress: string
): Promise<void> {
  const positions = await getPositions(matchId, playerAddress);

  const prices = getLatestPrices();
  const priceMap: Record<string, number> = {
    BTC: prices.btc,
    ETH: prices.eth,
    SOL: prices.sol,
  };

  let totalPnl = 0;
  let openCount = 0;

  for (const pos of positions) {
    if (pos.closedAt) {
      totalPnl += pos.pnl || 0;
    } else {
      openCount++;
      const currentPrice = priceMap[pos.assetSymbol] || pos.entryPrice;
      const priceDiff = pos.isLong
        ? currentPrice - pos.entryPrice
        : pos.entryPrice - currentPrice;
      totalPnl +=
        (priceDiff / pos.entryPrice) * pos.size * pos.leverage;
    }
  }

  broadcastToMatch(matchId, {
    type: "opponent_update",
    player: playerAddress,
    equity: DEMO_BALANCE + totalPnl,
    pnl: totalPnl,
    positionCount: openCount,
  });
}
