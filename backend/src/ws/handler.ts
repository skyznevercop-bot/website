import { Server as HttpServer } from "http";
import WebSocket, { WebSocketServer } from "ws";
import jwt from "jsonwebtoken";
import { PrismaClient } from "@prisma/client";
import { config } from "../config";
import {
  joinMatchRoom,
  leaveMatchRoom,
  registerUserConnection,
  unregisterUserConnection,
  broadcastToUser,
  broadcastToMatch,
} from "./rooms";
import { joinQueue, leaveQueue } from "../services/matchmaking";
import { getLatestPrices } from "../services/price-oracle";

const prisma = new PrismaClient();

interface AuthenticatedSocket extends WebSocket {
  userAddress?: string;
  currentMatchId?: string;
}

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
        ws.send(JSON.stringify({ type: "error", message: "Invalid message format" }));
      }
    });

    ws.on("close", () => {
      if (ws.userAddress) {
        unregisterUserConnection(ws.userAddress, ws);
        if (ws.currentMatchId) {
          leaveMatchRoom(ws.currentMatchId, ws);
        }
      }
      console.log(`[WS] Client disconnected: ${ws.userAddress}`);
    });
  });

  console.log("[WS] WebSocket server started on /ws");
}

async function handleMessage(
  ws: AuthenticatedSocket,
  data: Record<string, unknown>
): Promise<void> {
  if (!ws.userAddress) return;

  switch (data.type) {
    case "join_queue": {
      const { timeframe, bet } = data as {
        timeframe: string;
        bet: number;
      };
      const user = await prisma.user.findUnique({
        where: { walletAddress: ws.userAddress },
      });
      await joinQueue(ws.userAddress, timeframe, bet, user?.eloRating || 1200);
      ws.send(JSON.stringify({ type: "queue_joined", timeframe, bet }));
      break;
    }

    case "leave_queue": {
      const { timeframe, bet } = data as {
        timeframe: string;
        bet: number;
      };
      await leaveQueue(ws.userAddress, timeframe, bet);
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

      // Send current prices immediately.
      ws.send(
        JSON.stringify({ type: "price_update", ...getLatestPrices() })
      );
      break;
    }

    case "open_position": {
      const { matchId, asset, isLong, size, leverage, sl, tp } = data as {
        matchId: string;
        asset: string;
        isLong: boolean;
        size: number;
        leverage: number;
        sl?: number;
        tp?: number;
      };

      const prices = getLatestPrices();
      const priceMap: Record<string, number> = {
        BTC: prices.btc,
        ETH: prices.eth,
        SOL: prices.sol,
      };
      const entryPrice = priceMap[asset];
      if (!entryPrice) {
        ws.send(
          JSON.stringify({ type: "error", message: "Unknown asset" })
        );
        return;
      }

      const position = await prisma.position.create({
        data: {
          matchId,
          playerAddress: ws.userAddress,
          assetSymbol: asset,
          isLong,
          entryPrice,
          size,
          leverage,
          openedAt: new Date(),
        },
      });

      ws.send(
        JSON.stringify({
          type: "position_opened",
          position: {
            id: position.id,
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

      const position = await prisma.position.findUnique({
        where: { id: positionId },
      });
      if (!position || position.playerAddress !== ws.userAddress) {
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
      const exitPrice = priceMap[position.assetSymbol] || position.entryPrice;
      const priceDiff = position.isLong
        ? exitPrice - position.entryPrice
        : position.entryPrice - exitPrice;
      const pnl =
        (priceDiff / position.entryPrice) * position.size * position.leverage;

      await prisma.position.update({
        where: { id: positionId },
        data: { exitPrice, pnl, closedAt: new Date(), closeReason: "manual" },
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
  const positions = await prisma.position.findMany({
    where: { matchId, playerAddress },
  });

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
    equity: 1000 + totalPnl, // Starting balance + PnL
    pnl: totalPnl,
    positionCount: openCount,
  });
}
