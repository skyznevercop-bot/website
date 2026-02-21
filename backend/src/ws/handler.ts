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
  getUserConnectionCount,
} from "./rooms";
import { joinQueue, leaveQueue, removeFromAllQueues } from "../services/matchmaking";
import { isValidDuration, isValidBet } from "../utils/validation";
import { getLatestPrices } from "../services/price-oracle";
import {
  createPosition,
  getPositions,
  updatePosition,
  getMatch,
  getUser,
} from "../services/firebase";
import { settleByForfeit } from "../services/settlement";
import { getBalance, reconcileFrozenBalance } from "../services/balance";
import { calculatePnl, liquidationPrice, roiDecimal, roiToPercent } from "../utils/pnl";

const DEMO_BALANCE = config.demoInitialBalance;
const FORFEIT_GRACE_MS = config.wsForfeitGraceMs;
const MAX_CONNECTIONS_PER_USER = config.wsMaxConnectionsPerUser;
const WS_RATE_LIMIT_MAX = config.wsRateLimitMax;
const WS_RATE_LIMIT_WINDOW_MS = config.wsRateLimitWindowMs;
const WS_MAX_MESSAGE_BYTES = config.wsMaxMessageBytes;
const AUTH_TIMEOUT_MS = config.wsAuthTimeoutMs;
const PRICE_MAX_AGE_MS = config.priceMaxAgeMs;
const CHAT_MAX_LENGTH = config.chatMaxLength;

/** Guard against double-close: position IDs currently being closed. */
const _closingPositions = new Set<string>();

interface AuthenticatedSocket extends WebSocket {
  userAddress?: string;
  currentMatchId?: string;
  /** Whether the connection has completed authentication. */
  _authenticated?: boolean;
  /** Message rate limiting state. */
  _msgCount?: number;
  _msgWindowStart?: number;
  /** Whether a pong response is pending (heartbeat liveness check). */
  _isAlive?: boolean;
}

/** Active forfeit timers: "matchId|playerAddress" → timeout handle. */
const forfeitTimers = new Map<string, ReturnType<typeof setTimeout>>();

export { broadcastToUser };

export function setupWebSocket(server: HttpServer): void {
  const wss = new WebSocketServer({ server, path: "/ws" });

  // ── Heartbeat: detect dead connections via ping/pong ──
  const heartbeatInterval = setInterval(() => {
    for (const client of wss.clients) {
      const ws = client as AuthenticatedSocket;
      if (ws._isAlive === false) {
        // No pong received since last ping — connection is dead.
        console.warn(`[WS] Heartbeat timeout: ${ws.userAddress?.slice(0, 8) ?? "unauthenticated"} — terminating`);
        ws.terminate();
        continue;
      }
      ws._isAlive = false;
      ws.ping();
    }
  }, config.wsPingIntervalMs);

  wss.on("close", () => {
    clearInterval(heartbeatInterval);
  });

  wss.on("connection", (ws: AuthenticatedSocket) => {
    // Mark connection as alive on initial connect + on every pong.
    ws._isAlive = true;
    ws.on("pong", () => {
      ws._isAlive = true;
    });

    // Require authentication via the first WebSocket message instead of
    // query parameters (tokens in URLs leak into logs and browser history).
    ws._authenticated = false;

    // Close the connection if no auth message arrives within the timeout.
    const authTimer = setTimeout(() => {
      if (!ws._authenticated) {
        ws.close(4001, "Authentication timeout");
      }
    }, AUTH_TIMEOUT_MS);

    ws.on("message", async (raw) => {
      // ── First message must be auth ──
      if (!ws._authenticated) {
        clearTimeout(authTimer);
        try {
          const authData = JSON.parse(raw.toString());
          if (authData.type !== "auth" || typeof authData.token !== "string") {
            ws.close(4001, "First message must be { type: 'auth', token: '...' }");
            return;
          }

          const payload = jwt.verify(authData.token, config.jwtSecret) as {
            address: string;
          };

          // Enforce per-user connection limit to prevent resource exhaustion.
          if (getUserConnectionCount(payload.address) >= MAX_CONNECTIONS_PER_USER) {
            ws.close(4008, "Too many connections");
            return;
          }

          ws.userAddress = payload.address;
          ws._authenticated = true;
          registerUserConnection(payload.address, ws);

          // Cancel any pending forfeit timer for this player.
          cancelForfeitTimersForPlayer(payload.address);

          // Reconcile frozen balance then send updated balance on connect.
          reconcileFrozenBalance(payload.address)
            .then(() => sendBalanceUpdate(payload.address, ws))
            .catch((err) => {
              console.error(`[WS] Failed to reconcile/send balance for ${payload.address.slice(0, 8)}…:`, err);
            });

          console.log(`[WS] Client authenticated: ${ws.userAddress}`);
          ws.send(JSON.stringify({ type: "auth_ok" }));
          return;
        } catch {
          ws.close(4001, "Invalid authentication token");
          return;
        }
      }

      // ── Per-connection message rate limiting ──
      const now = Date.now();
      if (!ws._msgWindowStart || now - ws._msgWindowStart > WS_RATE_LIMIT_WINDOW_MS) {
        ws._msgWindowStart = now;
        ws._msgCount = 1;
      } else {
        ws._msgCount = (ws._msgCount ?? 0) + 1;
        if (ws._msgCount > WS_RATE_LIMIT_MAX) {
          ws.send(JSON.stringify({ type: "error", message: "Rate limit exceeded — slow down" }));
          return;
        }
      }

      // Reject oversized messages.
      const rawLen = Buffer.isBuffer(raw) ? raw.length : raw.toString().length;
      if (rawLen > WS_MAX_MESSAGE_BYTES) {
        ws.send(JSON.stringify({ type: "error", message: "Message too large" }));
        return;
      }

      try {
        const data = JSON.parse(raw.toString());
        await handleMessage(ws, data);
      } catch (err) {
        console.error(`[WS] Message handling error for ${ws.userAddress?.slice(0, 8) ?? "unknown"}:`, err);
        ws.send(
          JSON.stringify({ type: "error", message: "Invalid message format" })
        );
      }
    });

    ws.on("close", () => {
      if (ws.userAddress) {
        unregisterUserConnection(ws.userAddress, ws);

        // Only remove from queues if the user has NO other active connections.
        // This prevents brief WS blips from kicking players out of the queue.
        if (!isUserConnected(ws.userAddress)) {
          removeFromAllQueues(ws.userAddress).catch((err) => {
            console.error(`[WS] Failed to remove ${ws.userAddress?.slice(0, 8)}… from queues on disconnect:`, err);
          });
        }

        if (ws.currentMatchId) {
          leaveMatchRoom(ws.currentMatchId, ws);

          // Start forfeit timer if player has no other connections.
          if (!isUserConnected(ws.userAddress)) {
            startForfeitTimer(ws.currentMatchId, ws.userAddress);
          }
        }
      }
      console.log(`[WS] Client disconnected: ${ws.userAddress}`);
    });
  });

  // Broadcast prices + opponent updates for all active matches.
  setInterval(async () => {
    const matchIds = getActiveMatchIds();
    if (matchIds.length === 0) return;

    const prices = getLatestPrices();
    const priceMsg = JSON.stringify({ type: "price_update", ...prices });

    for (const matchId of matchIds) {
      const match = await getMatch(matchId);
      if (!match || match.status !== "active") continue;

      broadcastToMatch(matchId, JSON.parse(priceMsg));

      broadcastOpponentUpdate(matchId, match.player1).catch((err) => {
        console.error(`[WS] Opponent update failed for P1 in ${matchId}:`, err);
      });
      broadcastOpponentUpdate(matchId, match.player2).catch((err) => {
        console.error(`[WS] Opponent update failed for P2 in ${matchId}:`, err);
      });
    }
  }, config.opponentBroadcastIntervalMs);

  // Server-side SL/TP/liquidation monitor.
  setInterval(async () => {
    const matchIds = getActiveMatchIds();
    if (matchIds.length === 0) return;

    const prices = getLatestPrices();
    const priceMap: Record<string, number> = {
      BTC: prices.btc,
      ETH: prices.eth,
      SOL: prices.sol,
    };

    for (const matchId of matchIds) {
      const match = await getMatch(matchId);
      if (!match || match.status !== "active") continue;

      const positions = await getPositions(matchId);

      for (const pos of positions) {
        if (pos.closedAt) continue;
        if (_closingPositions.has(pos.id)) continue;

        const currentPrice = priceMap[pos.assetSymbol] ?? pos.entryPrice;

        // Liquidation: player loses 90% of margin.
        const liqPrice = liquidationPrice(pos);

        let closeReason: string | null = null;
        let exitPrice = currentPrice;

        if (pos.isLong ? currentPrice <= liqPrice : currentPrice >= liqPrice) {
          closeReason = "liquidation";
          exitPrice = liqPrice;
        } else if (pos.sl != null) {
          const slHit = pos.isLong ? currentPrice <= pos.sl : currentPrice >= pos.sl;
          if (slHit) { closeReason = "sl"; exitPrice = pos.sl; }
        }
        if (closeReason === null && pos.tp != null) {
          const tpHit = pos.isLong ? currentPrice >= pos.tp : currentPrice <= pos.tp;
          if (tpHit) { closeReason = "tp"; exitPrice = pos.tp; }
        }

        if (closeReason === null) continue;

        _closingPositions.add(pos.id);
        try {
          const pnl = calculatePnl(pos, exitPrice);

          await updatePosition(matchId, pos.id, {
            exitPrice,
            pnl,
            closedAt: Date.now(),
            closeReason,
          });

          broadcastToUser(pos.playerAddress, {
            type: "position_closed",
            positionId: pos.id,
            exitPrice,
            pnl,
            closeReason,
          });

          broadcastOpponentUpdate(matchId, pos.playerAddress).catch((err) => {
            console.error(`[WS] Opponent update failed after SL/TP close in ${matchId}:`, err);
          });
        } finally {
          _closingPositions.delete(pos.id);
        }
      }
    }
  }, config.settlementIntervalMs);

  console.log("[WS] WebSocket server started on /ws");
}

// ── Forfeit Timers ────────────────────────────────────────────

function startForfeitTimer(matchId: string, playerAddress: string): void {
  const key = `${matchId}|${playerAddress}`;
  if (forfeitTimers.has(key)) return;

  console.log(
    `[WS] Disconnect detected: ${playerAddress.slice(0, 8)}… in match ${matchId} — 60s grace period`
  );

  broadcastToMatch(matchId, {
    type: "opponent_disconnected",
    player: playerAddress,
    graceSeconds: 60,
  });

  const timer = setTimeout(async () => {
    forfeitTimers.delete(key);

    if (isUserConnected(playerAddress)) {
      console.log(`[WS] Player ${playerAddress.slice(0, 8)}… reconnected — forfeit cancelled`);
      return;
    }

    console.log(`[WS] Forfeit triggered: ${playerAddress.slice(0, 8)}… in match ${matchId}`);
    await settleByForfeit(matchId, playerAddress);
  }, FORFEIT_GRACE_MS);

  forfeitTimers.set(key, timer);
}

function cancelForfeitTimersForPlayer(playerAddress: string): void {
  for (const [key, timer] of forfeitTimers) {
    const [matchId, addr] = key.split("|");
    if (addr === playerAddress) {
      clearTimeout(timer);
      forfeitTimers.delete(key);
      console.log(`[WS] Forfeit timer cancelled for ${playerAddress.slice(0, 8)}… in match ${matchId}`);
      broadcastToMatch(matchId, { type: "opponent_reconnected", player: playerAddress });
    }
  }
}

function cancelForfeitTimerForMatch(matchId: string, playerAddress: string): void {
  const key = `${matchId}|${playerAddress}`;
  const timer = forfeitTimers.get(key);
  if (timer) {
    clearTimeout(timer);
    forfeitTimers.delete(key);
    console.log(`[WS] Forfeit timer cancelled for ${playerAddress.slice(0, 8)}… in match ${matchId}`);
    broadcastToMatch(matchId, { type: "opponent_reconnected", player: playerAddress });
  }
}

// ── Balance helper ────────────────────────────────────────────

async function sendBalanceUpdate(address: string, ws: WebSocket): Promise<void> {
  const balanceInfo = await getBalance(address);
  ws.send(JSON.stringify({
    type: "balance_update",
    ...balanceInfo,
  }));
}

// ── Message Handler ──────────────────────────────────────────

async function handleMessage(
  ws: AuthenticatedSocket,
  data: Record<string, unknown>
): Promise<void> {
  if (!ws.userAddress) return;

  switch (data.type) {
    case "join_queue": {
      const { duration, bet } = data as {
        duration: unknown;
        bet: unknown;
      };

      if (!isValidDuration(duration) || !isValidBet(bet)) {
        console.log(`[WS] join_queue rejected: invalid params — duration=${duration}, bet=${bet}, user=${ws.userAddress.slice(0, 8)}…`);
        ws.send(JSON.stringify({ type: "error", message: "Invalid duration or bet amount" }));
        return;
      }

      const success = await joinQueue(ws.userAddress, duration, bet);
      if (!success) {
        console.log(`[WS] join_queue rejected: insufficient balance — user=${ws.userAddress.slice(0, 8)}…, bet=${bet}`);
        ws.send(JSON.stringify({
          type: "error",
          message: "Insufficient balance",
        }));
        return;
      }

      console.log(`[WS] join_queue success: ${ws.userAddress.slice(0, 8)}… → ${duration} / $${bet}`);
      ws.send(JSON.stringify({ type: "queue_joined", duration, bet }));

      // Send updated balance (frozen amount changed).
      sendBalanceUpdate(ws.userAddress, ws).catch((err) => {
        console.error(`[WS] Failed to send balance update for ${ws.userAddress?.slice(0, 8)}…:`, err);
      });
      break;
    }

    case "leave_queue": {
      const { duration, bet } = data as {
        duration?: unknown;
        bet?: unknown;
      };
      if (isValidDuration(duration) && isValidBet(bet)) {
        await leaveQueue(ws.userAddress, duration, bet);
      } else {
        await removeFromAllQueues(ws.userAddress);
      }
      ws.send(JSON.stringify({ type: "queue_left" }));

      // Send updated balance (unfrozen).
      sendBalanceUpdate(ws.userAddress, ws).catch((err) => {
        console.error(`[WS] Failed to send balance update for ${ws.userAddress?.slice(0, 8)}…:`, err);
      });
      break;
    }

    case "join_match": {
      const { matchId } = data as { matchId: string };

      // Verify the user is actually a player in this match before joining.
      // Without this check, any user could join a match room and trigger
      // a forfeit on disconnect, force-settling the match.
      const joinMatchData = await getMatch(matchId);
      if (!joinMatchData ||
          (ws.userAddress !== joinMatchData.player1 && ws.userAddress !== joinMatchData.player2)) {
        ws.send(JSON.stringify({ type: "error", message: "Not a player in this match" }));
        break;
      }

      if (ws.currentMatchId) {
        leaveMatchRoom(ws.currentMatchId, ws);
      }
      ws.currentMatchId = matchId;
      joinMatchRoom(matchId, ws);

      cancelForfeitTimerForMatch(matchId, ws.userAddress);

      // Send current prices immediately.
      ws.send(
        JSON.stringify({ type: "price_update", ...getLatestPrices() })
      );

      // Send a position snapshot for UI recovery after page refresh.
      const snapMatch = joinMatchData;
      if (snapMatch && snapMatch.status === "active") {
        const snapPositions = await getPositions(matchId, ws.userAddress);

        let balance = DEMO_BALANCE;
        for (const pos of snapPositions) {
          if (!pos.closedAt) {
            balance -= pos.size;
          } else {
            balance += (pos.pnl ?? 0);
          }
        }

        ws.send(JSON.stringify({
          type: "match_snapshot",
          positions: snapPositions.map(pos => ({
            id:          pos.id,
            assetSymbol: pos.assetSymbol,
            isLong:      pos.isLong,
            entryPrice:  pos.entryPrice,
            size:        pos.size,
            leverage:    pos.leverage,
            stopLoss:    pos.sl   ?? null,
            takeProfit:  pos.tp   ?? null,
            openedAt:    pos.openedAt,
            exitPrice:   pos.exitPrice  ?? null,
            closedAt:    pos.closedAt   ?? null,
            closeReason: pos.closeReason ?? null,
          })),
          balance,
        }));
      }

      // Re-send match_end if already settled (covers reconnect after match ended).
      if (snapMatch) {
        const settled = ["completed", "tied", "forfeited"];
        if (settled.includes(snapMatch.status)) {
          ws.send(JSON.stringify({
            type: "match_end",
            matchId,
            winner: snapMatch.winner || null,
            player1: snapMatch.player1,
            player2: snapMatch.player2,
            p1Roi: snapMatch.player1Roi != null
              ? Math.round(snapMatch.player1Roi * 10000) / 100
              : 0,
            p2Roi: snapMatch.player2Roi != null
              ? Math.round(snapMatch.player2Roi * 10000) / 100
              : 0,
            isTie: snapMatch.status === "tied",
            isForfeit: snapMatch.status === "forfeited",
          }));
        }
      }
      break;
    }

    case "open_position": {
      const { matchId, asset, isLong, size, leverage, sl, tp, positionId: localPositionId } = data as {
        matchId: string;
        asset: string;
        isLong: boolean;
        size: number;
        leverage: number;
        sl?: number;
        tp?: number;
        positionId?: string;
      };

      if (typeof isLong !== "boolean") {
        ws.send(JSON.stringify({ type: "error", message: "isLong must be a boolean" }));
        return;
      }

      const matchData = await getMatch(matchId);
      if (!matchData || matchData.status !== "active") {
        ws.send(JSON.stringify({ type: "error", message: "Match is not active" }));
        return;
      }
      if (ws.userAddress !== matchData.player1 && ws.userAddress !== matchData.player2) {
        ws.send(JSON.stringify({ type: "error", message: "Not a player in this match" }));
        return;
      }

      if (typeof size !== "number" || !Number.isFinite(size) || size < 1 || size > DEMO_BALANCE) {
        ws.send(JSON.stringify({ type: "error", message: "Invalid position size (1 – $1M)" }));
        return;
      }
      if (typeof leverage !== "number" || !Number.isFinite(leverage) || leverage < 1 || leverage > config.maxLeverage) {
        ws.send(JSON.stringify({ type: "error", message: `Invalid leverage (1x – ${config.maxLeverage}x)` }));
        return;
      }
      if (!config.validAssets.includes(asset)) {
        ws.send(JSON.stringify({ type: "error", message: "Unknown asset" }));
        return;
      }

      if (localPositionId != null && !/^[a-zA-Z0-9_-]{1,64}$/.test(localPositionId)) {
        ws.send(JSON.stringify({ type: "error", message: "Invalid position ID format" }));
        return;
      }

      // Idempotency check.
      if (localPositionId != null) {
        const existing = await getPositions(matchId, ws.userAddress);
        const dup = existing.find((p) => p.id === localPositionId);
        if (dup) {
          ws.send(JSON.stringify({
            type: "position_opened",
            position: {
              id: dup.id,
              asset: dup.assetSymbol,
              isLong: dup.isLong,
              entryPrice: dup.entryPrice,
              size: dup.size,
              leverage: dup.leverage,
            },
          }));
          return;
        }
      }

      // Balance check.
      const openPositions = await getPositions(matchId, ws.userAddress);
      const usedMargin = openPositions
        .filter((p) => !p.closedAt)
        .reduce((sum, p) => sum + p.size, 0);
      if (size > DEMO_BALANCE - usedMargin) {
        ws.send(JSON.stringify({ type: "error", message: "Insufficient balance" }));
        return;
      }

      const prices = getLatestPrices();
      if (Date.now() - prices.timestamp > PRICE_MAX_AGE_MS) {
        ws.send(JSON.stringify({ type: "error", message: "Price data is stale — try again shortly" }));
        return;
      }

      const priceMap: Record<string, number> = {
        BTC: prices.btc,
        ETH: prices.eth,
        SOL: prices.sol,
      };
      const entryPrice = priceMap[asset];
      if (!entryPrice) {
        ws.send(JSON.stringify({ type: "error", message: "Price unavailable" }));
        return;
      }

      // Validate SL/TP direction.
      if (sl != null) {
        if (typeof sl !== "number" || !Number.isFinite(sl) || sl <= 0) {
          ws.send(JSON.stringify({ type: "error", message: "Invalid stop loss" }));
          return;
        }
        const slValid = isLong ? sl < entryPrice : sl > entryPrice;
        if (!slValid) {
          ws.send(JSON.stringify({ type: "error", message: "SL must be below entry for longs, above for shorts" }));
          return;
        }
      }
      if (tp != null) {
        if (typeof tp !== "number" || !Number.isFinite(tp) || tp <= 0) {
          ws.send(JSON.stringify({ type: "error", message: "Invalid take profit" }));
          return;
        }
        const tpValid = isLong ? tp > entryPrice : tp < entryPrice;
        if (!tpValid) {
          ws.send(JSON.stringify({ type: "error", message: "TP must be above entry for longs, below for shorts" }));
          return;
        }
      }

      const positionId = await createPosition(
        matchId,
        {
          playerAddress: ws.userAddress,
          assetSymbol: asset,
          isLong,
          entryPrice,
          size,
          leverage,
          ...(sl != null && { sl }),
          ...(tp != null && { tp }),
          openedAt: Date.now(),
        },
        localPositionId
      );

      ws.send(JSON.stringify({
        type: "position_opened",
        position: {
          id: positionId,
          asset,
          isLong,
          entryPrice,
          size,
          leverage,
        },
      }));

      broadcastOpponentUpdate(matchId, ws.userAddress);
      break;
    }

    case "close_position": {
      const { matchId, positionId } = data as {
        matchId: string;
        positionId: string;
      };

      const closeMatchData = await getMatch(matchId);
      if (!closeMatchData || closeMatchData.status !== "active") {
        ws.send(JSON.stringify({ type: "error", message: "Match is not active" }));
        return;
      }
      if (ws.userAddress !== closeMatchData.player1 && ws.userAddress !== closeMatchData.player2) {
        ws.send(JSON.stringify({ type: "error", message: "Not a player in this match" }));
        return;
      }

      const positions = await getPositions(matchId, ws.userAddress);
      const position = positions.find(
        (p) => p.id === positionId && !p.closedAt
      );

      if (!position) {
        ws.send(JSON.stringify({ type: "error", message: "Position not found" }));
        return;
      }

      if (_closingPositions.has(positionId)) {
        ws.send(JSON.stringify({ type: "error", message: "Position is already being closed" }));
        return;
      }

      _closingPositions.add(positionId);
      try {
        const prices = getLatestPrices();
        if (Date.now() - prices.timestamp > PRICE_MAX_AGE_MS) {
          ws.send(JSON.stringify({ type: "error", message: "Price data is stale — try again shortly" }));
          return;
        }

        const priceMap: Record<string, number> = {
          BTC: prices.btc,
          ETH: prices.eth,
          SOL: prices.sol,
        };
        const exitPrice = priceMap[position.assetSymbol] ?? position.entryPrice;
        const pnl = calculatePnl(position, exitPrice);

        await updatePosition(matchId, positionId, {
          exitPrice,
          pnl,
          closedAt: Date.now(),
          closeReason: "manual",
        });

        ws.send(JSON.stringify({
          type: "position_closed",
          positionId,
          exitPrice,
          pnl,
        }));

        broadcastOpponentUpdate(matchId, ws.userAddress);
      } finally {
        _closingPositions.delete(positionId);
      }
      break;
    }

    case "partial_close": {
      const { matchId, positionId, fraction } = data as {
        matchId: string;
        positionId: string;
        fraction: number;
      };

      if (typeof fraction !== "number" || !Number.isFinite(fraction) || fraction <= 0 || fraction >= 1) {
        ws.send(JSON.stringify({ type: "error", message: "Invalid fraction (must be between 0 and 1)" }));
        return;
      }

      const partialMatchData = await getMatch(matchId);
      if (!partialMatchData || partialMatchData.status !== "active") {
        ws.send(JSON.stringify({ type: "error", message: "Match is not active" }));
        return;
      }
      if (ws.userAddress !== partialMatchData.player1 && ws.userAddress !== partialMatchData.player2) {
        ws.send(JSON.stringify({ type: "error", message: "Not a player in this match" }));
        return;
      }

      const partialPositions = await getPositions(matchId, ws.userAddress);
      const partialPos = partialPositions.find(
        (p) => p.id === positionId && !p.closedAt
      );

      if (!partialPos) {
        ws.send(JSON.stringify({ type: "error", message: "Position not found" }));
        return;
      }

      if (_closingPositions.has(positionId)) {
        ws.send(JSON.stringify({ type: "error", message: "Position is already being closed" }));
        return;
      }

      _closingPositions.add(positionId);
      try {
        const prices = getLatestPrices();
        const priceMap: Record<string, number> = {
          BTC: prices.btc,
          ETH: prices.eth,
          SOL: prices.sol,
        };
        const exitPrice = priceMap[partialPos.assetSymbol] ?? partialPos.entryPrice;

        const partialSize = partialPos.size * fraction;
        const remainingSize = partialPos.size - partialSize;

        const partialPnl = calculatePnl(
          { ...partialPos, size: partialSize },
          exitPrice
        );

        // 1. Create a new closed position for the partial amount.
        const partialId = `${positionId}_partial_${Date.now()}`;
        await createPosition(
          matchId,
          {
            playerAddress: ws.userAddress,
            assetSymbol: partialPos.assetSymbol,
            isLong: partialPos.isLong,
            entryPrice: partialPos.entryPrice,
            size: partialSize,
            leverage: partialPos.leverage,
            exitPrice,
            pnl: partialPnl,
            openedAt: partialPos.openedAt,
            closedAt: Date.now(),
            closeReason: "partial",
          },
          partialId
        );

        // 2. Update the original position's size (reduced).
        await updatePosition(matchId, positionId, {
          size: remainingSize,
        });

        // 3. Notify the client.
        broadcastToUser(ws.userAddress, {
          type: "position_closed",
          positionId: partialId,
          exitPrice,
          pnl: partialPnl,
          closeReason: "partial",
        });

        broadcastOpponentUpdate(matchId, ws.userAddress);
      } finally {
        _closingPositions.delete(positionId);
      }
      break;
    }

    case "chat_message": {
      const { matchId, content } = data as {
        matchId: string;
        content: string;
      };

      if (
        !matchId ||
        !content ||
        typeof content !== "string" ||
        content.length > CHAT_MAX_LENGTH
      ) {
        break;
      }

      // Sanitize: strip control characters and trim whitespace.
      // eslint-disable-next-line no-control-regex
      const sanitized = content.replace(/[\x00-\x1F\x7F]/g, "").trim();
      if (sanitized.length === 0) break;

      // Look up the server-side gamer tag to prevent spoofing.
      const chatUser = await getUser(ws.userAddress!);
      const serverTag = chatUser?.gamerTag || ws.userAddress!.slice(0, 8);

      broadcastToMatch(matchId, {
        type: "chat_message",
        matchId,
        senderTag: serverTag,
        content: sanitized,
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
 * Calculate a player's stats and send them only to their opponent.
 */
async function broadcastOpponentUpdate(
  matchId: string,
  playerAddress: string
): Promise<void> {
  const match = await getMatch(matchId);
  if (!match) return;

  const opponentAddress =
    match.player1 === playerAddress ? match.player2 : match.player1;

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
      totalPnl += pos.pnl ?? 0;
    } else {
      openCount++;
      const currentPrice = priceMap[pos.assetSymbol] ?? pos.entryPrice;
      totalPnl += calculatePnl(pos, currentPrice);
    }
  }

  const roi = roiToPercent(roiDecimal(totalPnl, DEMO_BALANCE));

  broadcastToUser(opponentAddress, {
    type: "opponent_update",
    player: playerAddress,
    equity: DEMO_BALANCE + totalPnl,
    pnl: totalPnl,
    positionCount: openCount,
    roi,
  });
}
