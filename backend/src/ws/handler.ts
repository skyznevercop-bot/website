import { Server as HttpServer } from "http";
import WebSocket, { WebSocketServer } from "ws";
import jwt from "jsonwebtoken";
import { config } from "../config";
import { log } from "../utils/logger";
import {
  joinMatchRoom,
  leaveMatchRoom,
  registerUserConnection,
  unregisterUserConnection,
  broadcastToUser,
  broadcastToMatch,
  broadcastToSpectators,
  broadcastToMatchAndSpectators,
  joinSpectatorRoom,
  leaveSpectatorRoom,
  getSpectatorCount,
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

/** Seconds to wait for a pong reply before terminating the connection. */
const PONG_TIMEOUT_MS = 10_000;

interface AuthenticatedSocket extends WebSocket {
  userAddress?: string;
  currentMatchId?: string;
  /** Whether the connection has completed authentication. */
  _authenticated?: boolean;
  /** Whether this connection is a read-only spectator (no auth required). */
  _isSpectator?: boolean;
  /** Message rate limiting state. */
  _msgCount?: number;
  _msgWindowStart?: number;
  /** Whether a pong response is pending (heartbeat liveness check). */
  _isAlive?: boolean;
  /** Explicit pong deadline timer — fires PONG_TIMEOUT_MS after a ping. */
  _pongTimer?: ReturnType<typeof setTimeout>;
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
        log.warn("heartbeat_timeout", { user: ws.userAddress?.slice(0, 8) ?? "unauthenticated" });
        ws.terminate();
        continue;
      }
      ws._isAlive = false;
      ws.ping();

      // Explicit pong deadline: if no pong arrives within PONG_TIMEOUT_MS,
      // terminate immediately instead of waiting for the next heartbeat cycle.
      if (ws._pongTimer) clearTimeout(ws._pongTimer);
      ws._pongTimer = setTimeout(() => {
        if (ws._isAlive === false && ws.readyState === WebSocket.OPEN) {
          log.warn("pong_timeout", { user: ws.userAddress?.slice(0, 8) ?? "unauthenticated", deadlineMs: PONG_TIMEOUT_MS });
          ws.terminate();
        }
      }, PONG_TIMEOUT_MS);
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
      if (ws._pongTimer) { clearTimeout(ws._pongTimer); ws._pongTimer = undefined; }
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
      // ── First message must be auth OR spectate_match ──
      if (!ws._authenticated) {
        clearTimeout(authTimer);
        try {
          const authData = JSON.parse(raw.toString());

          // ── Spectator mode: no JWT needed ──
          if (authData.type === "spectate_match" && typeof authData.matchId === "string") {
            const matchId = authData.matchId as string;
            const spectateMatch = await getMatch(matchId);
            if (!spectateMatch || spectateMatch.status === "cancelled") {
              ws.close(4004, "Match not found");
              return;
            }

            ws._isSpectator = true;
            ws._authenticated = true;
            ws.currentMatchId = matchId;
            joinSpectatorRoom(matchId, ws);

            // Send spectator snapshot with both players' stats.
            await sendSpectatorSnapshot(ws, matchId, spectateMatch);

            log.info("spectator_joined", { matchId, spectators: getSpectatorCount(matchId) });
            return;
          }

          // ── Standard auth flow ──
          if (authData.type !== "auth" || typeof authData.token !== "string") {
            ws.close(4001, "First message must be { type: 'auth', token: '...' } or { type: 'spectate_match', matchId: '...' }");
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
              log.error("balance_reconcile_failed", { user: payload.address.slice(0, 8), error: String(err) });
            });

          log.info("client_authenticated", { user: ws.userAddress });
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
          log.warn("rate_limit_exceeded", { user: ws.userAddress?.slice(0, 8), count: ws._msgCount, windowMs: WS_RATE_LIMIT_WINDOW_MS });
          // Try to extract positionId so client can roll back phantom positions.
          let positionId: string | undefined;
          try {
            const parsed = JSON.parse(raw.toString());
            if (parsed.type === "open_position" && typeof parsed.positionId === "string") {
              positionId = parsed.positionId;
            }
          } catch { /* ignore parse errors */ }
          ws.send(JSON.stringify({
            type: "error",
            message: "Rate limit exceeded — slow down",
            ...(positionId != null && { positionId }),
          }));
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
        log.error("message_handling_error", { user: ws.userAddress?.slice(0, 8) ?? "unknown", error: String(err) });
        // Try to extract positionId so client can roll back phantom positions.
        let positionId: string | undefined;
        try {
          const parsed = JSON.parse(raw.toString());
          if (parsed.type === "open_position" && typeof parsed.positionId === "string") {
            positionId = parsed.positionId;
          }
        } catch { /* ignore parse errors */ }
        ws.send(
          JSON.stringify({
            type: "error",
            message: "Invalid message format",
            ...(positionId != null && { positionId }),
          })
        );
      }
    });

    ws.on("close", () => {
      // ── Spectator disconnect: just leave the spectator room ──
      if (ws._isSpectator) {
        if (ws.currentMatchId) {
          leaveSpectatorRoom(ws.currentMatchId, ws);
          log.info("spectator_left", { matchId: ws.currentMatchId, spectators: getSpectatorCount(ws.currentMatchId) });
        }
        return;
      }

      if (ws.userAddress) {
        unregisterUserConnection(ws.userAddress, ws);

        // Only remove from queues if the user has NO other active connections.
        // This prevents brief WS blips from kicking players out of the queue.
        if (!isUserConnected(ws.userAddress)) {
          removeFromAllQueues(ws.userAddress).catch((err) => {
            log.error("queue_remove_failed", { user: ws.userAddress?.slice(0, 8), error: String(err) });
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
      log.info("client_disconnected", { user: ws.userAddress ?? "unauthenticated", matchId: ws.currentMatchId ?? null });
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
        log.error("opponent_update_failed", { matchId, player: "p1", error: String(err) });
      });
      broadcastOpponentUpdate(matchId, match.player2).catch((err) => {
        log.error("opponent_update_failed", { matchId, player: "p2", error: String(err) });
      });

      // Broadcast combined stats to spectators.
      if (getSpectatorCount(matchId) > 0) {
        broadcastSpectatorUpdate(matchId, match).catch((err) => {
          log.error("spectator_update_failed", { matchId, error: String(err) });
        });
      }
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

        // Liquidation: player loses 100% of margin.
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

          log.info("position_auto_closed", {
            matchId,
            positionId: pos.id,
            user: pos.playerAddress.slice(0, 8),
            asset: pos.assetSymbol,
            reason: closeReason,
            entryPrice: pos.entryPrice,
            exitPrice,
            pnl,
          });

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
            log.error("opponent_update_failed", { matchId, player: pos.playerAddress.slice(0, 8), trigger: closeReason, error: String(err) });
          });

          // Also send the opponent's stats back to the player whose
          // position was auto-closed so their opponent-ROI stays fresh.
          const autoCloseOpponent =
            match.player1 === pos.playerAddress
              ? match.player2
              : match.player1;
          broadcastOpponentUpdate(matchId, autoCloseOpponent).catch(() => {});
        } finally {
          _closingPositions.delete(pos.id);
        }
      }
    }
  }, config.settlementIntervalMs);

  log.info("ws_server_started", { path: "/ws", pingIntervalMs: config.wsPingIntervalMs, pongTimeoutMs: PONG_TIMEOUT_MS });
}

// ── Forfeit Timers ────────────────────────────────────────────

function startForfeitTimer(matchId: string, playerAddress: string): void {
  const key = `${matchId}|${playerAddress}`;
  if (forfeitTimers.has(key)) return;

  log.info("forfeit_timer_started", { matchId, user: playerAddress.slice(0, 8), graceMs: FORFEIT_GRACE_MS });

  broadcastToMatchAndSpectators(matchId, {
    type: "opponent_disconnected",
    player: playerAddress,
    graceSeconds: 60,
  });

  const timer = setTimeout(async () => {
    forfeitTimers.delete(key);

    if (isUserConnected(playerAddress)) {
      log.info("forfeit_cancelled_reconnected", { matchId, user: playerAddress.slice(0, 8) });
      return;
    }

    log.warn("forfeit_triggered", { matchId, user: playerAddress.slice(0, 8) });
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
      log.info("forfeit_timer_cancelled", { matchId, user: playerAddress.slice(0, 8) });
      broadcastToMatchAndSpectators(matchId, { type: "opponent_reconnected", player: playerAddress });
    }
  }
}

function cancelForfeitTimerForMatch(matchId: string, playerAddress: string): void {
  const key = `${matchId}|${playerAddress}`;
  const timer = forfeitTimers.get(key);
  if (timer) {
    clearTimeout(timer);
    forfeitTimers.delete(key);
    log.info("forfeit_timer_cancelled", { matchId, user: playerAddress.slice(0, 8) });
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
  // Spectators are read-only — block all game actions.
  if (ws._isSpectator) {
    ws.send(JSON.stringify({ type: "error", message: "Spectators cannot perform actions" }));
    return;
  }
  if (!ws.userAddress) return;

  switch (data.type) {
    case "join_queue": {
      const { duration, bet } = data as {
        duration: unknown;
        bet: unknown;
      };

      if (!isValidDuration(duration) || !isValidBet(bet)) {
        log.warn("join_queue_rejected", { user: ws.userAddress.slice(0, 8), reason: "invalid_params", duration, bet });
        ws.send(JSON.stringify({ type: "error", message: "Invalid duration or bet amount" }));
        return;
      }

      const success = await joinQueue(ws.userAddress, duration, bet);
      if (!success) {
        log.warn("join_queue_rejected", { user: ws.userAddress.slice(0, 8), reason: "insufficient_balance", bet });
        ws.send(JSON.stringify({
          type: "error",
          message: "Insufficient balance",
        }));
        return;
      }

      log.info("join_queue_success", { user: ws.userAddress.slice(0, 8), duration, bet });
      ws.send(JSON.stringify({ type: "queue_joined", duration, bet }));

      // Send updated balance (frozen amount changed).
      sendBalanceUpdate(ws.userAddress, ws).catch((err) => {
        log.error("balance_update_failed", { user: ws.userAddress?.slice(0, 8), trigger: "join_queue", error: String(err) });
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
        log.error("balance_update_failed", { user: ws.userAddress?.slice(0, 8), trigger: "leave_queue", error: String(err) });
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

      // Helper: send error with positionId so client can roll back phantom positions.
      const sendOpenError = (message: string) => {
        ws.send(JSON.stringify({
          type: "error",
          message,
          ...(localPositionId != null && { positionId: localPositionId }),
        }));
      };

      if (typeof isLong !== "boolean") {
        sendOpenError("isLong must be a boolean");
        return;
      }

      const matchData = await getMatch(matchId);
      if (!matchData || matchData.status !== "active") {
        sendOpenError("Match is not active");
        return;
      }
      if (ws.userAddress !== matchData.player1 && ws.userAddress !== matchData.player2) {
        sendOpenError("Not a player in this match");
        return;
      }

      if (typeof size !== "number" || !Number.isFinite(size) || size < 1 || size > DEMO_BALANCE) {
        sendOpenError("Invalid position size (1 – $1M)");
        return;
      }
      if (typeof leverage !== "number" || !Number.isFinite(leverage) || leverage < 1 || leverage > config.maxLeverage) {
        sendOpenError(`Invalid leverage (1x – ${config.maxLeverage}x)`);
        return;
      }
      if (!config.validAssets.includes(asset)) {
        sendOpenError("Unknown asset");
        return;
      }

      if (localPositionId != null && !/^[a-zA-Z0-9_-]{1,64}$/.test(localPositionId)) {
        sendOpenError("Invalid position ID format");
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
        sendOpenError("Insufficient balance");
        return;
      }

      const prices = getLatestPrices();
      if (Date.now() - prices.timestamp > PRICE_MAX_AGE_MS) {
        sendOpenError("Price data is stale — try again shortly");
        return;
      }

      const priceMap: Record<string, number> = {
        BTC: prices.btc,
        ETH: prices.eth,
        SOL: prices.sol,
      };
      const entryPrice = priceMap[asset];
      if (!entryPrice) {
        sendOpenError("Price unavailable");
        return;
      }

      // Validate SL/TP direction.
      if (sl != null) {
        if (typeof sl !== "number" || !Number.isFinite(sl) || sl <= 0) {
          sendOpenError("Invalid stop loss");
          return;
        }
        const slValid = isLong ? sl < entryPrice : sl > entryPrice;
        if (!slValid) {
          sendOpenError("SL must be below entry for longs, above for shorts");
          return;
        }
      }
      if (tp != null) {
        if (typeof tp !== "number" || !Number.isFinite(tp) || tp <= 0) {
          sendOpenError("Invalid take profit");
          return;
        }
        const tpValid = isLong ? tp > entryPrice : tp < entryPrice;
        if (!tpValid) {
          sendOpenError("TP must be above entry for longs, below for shorts");
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

        // Send the closing user's updated stats to their opponent.
        broadcastOpponentUpdate(matchId, ws.userAddress);

        // Also send the opponent's stats back to the closing user so their
        // opponent-ROI display stays fresh immediately after close.
        const closeOpponent =
          closeMatchData.player1 === ws.userAddress
            ? closeMatchData.player2
            : closeMatchData.player1;
        broadcastOpponentUpdate(matchId, closeOpponent);
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

        // Also send the opponent's stats back to the closing user.
        const partialOpponent =
          partialMatchData.player1 === ws.userAddress
            ? partialMatchData.player2
            : partialMatchData.player1;
        broadcastOpponentUpdate(matchId, partialOpponent);
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

      broadcastToMatchAndSpectators(matchId, {
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

// ── Player stats helper (shared by opponent + spectator broadcasts) ──

interface PlayerStats {
  totalPnl: number;
  openCount: number;
  roi: number;
  equity: number;
}

interface SpectatorPositionSummary {
  asset: string;
  isLong: boolean;
  leverage: number;
  size: number;
  entryPrice: number;
  pnl: number;
}

async function computePlayerStats(
  matchId: string,
  playerAddress: string
): Promise<PlayerStats> {
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
  return { totalPnl, openCount, roi, equity: DEMO_BALANCE + totalPnl };
}

/**
 * Get open positions summary for spectators (no SL/TP details).
 */
async function getSpectatorPositions(
  matchId: string,
  playerAddress: string
): Promise<SpectatorPositionSummary[]> {
  const positions = await getPositions(matchId, playerAddress);
  const prices = getLatestPrices();
  const priceMap: Record<string, number> = {
    BTC: prices.btc,
    ETH: prices.eth,
    SOL: prices.sol,
  };

  return positions
    .filter((p) => !p.closedAt)
    .map((p) => ({
      asset: p.assetSymbol,
      isLong: p.isLong,
      leverage: p.leverage,
      size: p.size,
      entryPrice: p.entryPrice,
      pnl: calculatePnl(p, priceMap[p.assetSymbol] ?? p.entryPrice),
    }));
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

  const stats = await computePlayerStats(matchId, playerAddress);

  broadcastToUser(opponentAddress, {
    type: "opponent_update",
    player: playerAddress,
    equity: stats.equity,
    pnl: stats.totalPnl,
    positionCount: stats.openCount,
    roi: stats.roi,
  });
}

/**
 * Broadcast both players' high-level stats to all spectators of a match.
 */
async function broadcastSpectatorUpdate(
  matchId: string,
  match: { player1: string; player2: string }
): Promise<void> {
  const [p1Stats, p2Stats, p1User, p2User, p1Positions, p2Positions] = await Promise.all([
    computePlayerStats(matchId, match.player1),
    computePlayerStats(matchId, match.player2),
    getUser(match.player1),
    getUser(match.player2),
    getSpectatorPositions(matchId, match.player1),
    getSpectatorPositions(matchId, match.player2),
  ]);

  broadcastToSpectators(matchId, {
    type: "spectator_update",
    player1: {
      address: match.player1,
      gamerTag: p1User?.gamerTag || match.player1.slice(0, 8),
      roi: p1Stats.roi,
      equity: p1Stats.equity,
      positionCount: p1Stats.openCount,
      positions: p1Positions,
    },
    player2: {
      address: match.player2,
      gamerTag: p2User?.gamerTag || match.player2.slice(0, 8),
      roi: p2Stats.roi,
      equity: p2Stats.equity,
      positionCount: p2Stats.openCount,
      positions: p2Positions,
    },
    spectatorCount: getSpectatorCount(matchId),
  });
}

/**
 * Send initial spectator snapshot when a spectator joins a match.
 */
async function sendSpectatorSnapshot(
  ws: WebSocket,
  matchId: string,
  match: { player1: string; player2: string; duration?: string; betAmount?: number; startTime?: number; endTime?: number; status: string; winner?: string; player1Roi?: number; player2Roi?: number }
): Promise<void> {
  const [p1Stats, p2Stats, p1User, p2User, p1Positions, p2Positions] = await Promise.all([
    computePlayerStats(matchId, match.player1),
    computePlayerStats(matchId, match.player2),
    getUser(match.player1),
    getUser(match.player2),
    getSpectatorPositions(matchId, match.player1),
    getSpectatorPositions(matchId, match.player2),
  ]);

  const prices = getLatestPrices();
  const settled = ["completed", "tied", "forfeited"];
  const isEnded = settled.includes(match.status);

  ws.send(JSON.stringify({
    type: "spectator_snapshot",
    matchId,
    player1: {
      address: match.player1,
      gamerTag: p1User?.gamerTag || match.player1.slice(0, 8),
      roi: isEnded && match.player1Roi != null ? Math.round(match.player1Roi * 10000) / 100 : p1Stats.roi,
      equity: p1Stats.equity,
      positionCount: p1Stats.openCount,
      positions: p1Positions,
    },
    player2: {
      address: match.player2,
      gamerTag: p2User?.gamerTag || match.player2.slice(0, 8),
      roi: isEnded && match.player2Roi != null ? Math.round(match.player2Roi * 10000) / 100 : p2Stats.roi,
      equity: p2Stats.equity,
      positionCount: p2Stats.openCount,
      positions: p2Positions,
    },
    duration: match.duration || "5m",
    betAmount: match.betAmount || 0,
    startTime: match.startTime || Date.now(),
    endTime: match.endTime || Date.now(),
    status: match.status,
    winner: match.winner || null,
    spectatorCount: getSpectatorCount(matchId),
    prices: { btc: prices.btc, eth: prices.eth, sol: prices.sol },
  }));
}
