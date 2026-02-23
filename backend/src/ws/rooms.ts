import WebSocket from "ws";

/** Map of matchId → set of connected WebSocket clients. */
const matchRooms = new Map<string, Set<WebSocket>>();

/** Map of userAddress → set of connected WebSocket clients. */
const userConnections = new Map<string, Set<WebSocket>>();

/** Map of matchId → set of spectator WebSocket clients. */
const spectatorRooms = new Map<string, Set<WebSocket>>();

export function joinMatchRoom(matchId: string, ws: WebSocket): void {
  if (!matchRooms.has(matchId)) {
    matchRooms.set(matchId, new Set());
  }
  matchRooms.get(matchId)!.add(ws);
}

export function leaveMatchRoom(matchId: string, ws: WebSocket): void {
  const room = matchRooms.get(matchId);
  if (room) {
    room.delete(ws);
    if (room.size === 0) matchRooms.delete(matchId);
  }
}

// ── Spectator room management ──

export function joinSpectatorRoom(matchId: string, ws: WebSocket): void {
  if (!spectatorRooms.has(matchId)) {
    spectatorRooms.set(matchId, new Set());
  }
  spectatorRooms.get(matchId)!.add(ws);
}

export function leaveSpectatorRoom(matchId: string, ws: WebSocket): void {
  const room = spectatorRooms.get(matchId);
  if (room) {
    room.delete(ws);
    if (room.size === 0) spectatorRooms.delete(matchId);
  }
}

export function getSpectatorCount(matchId: string): number {
  return spectatorRooms.get(matchId)?.size ?? 0;
}

/**
 * Broadcast a message to spectators of a specific match.
 * Special key "__all_active__" broadcasts to ALL spectator rooms.
 */
export function broadcastToSpectators(
  matchId: string,
  data: Record<string, unknown>
): void {
  const message = JSON.stringify(data);

  if (matchId === "__all_active__") {
    for (const [, room] of spectatorRooms) {
      for (const ws of room) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(message);
        }
      }
    }
    return;
  }

  const room = spectatorRooms.get(matchId);
  if (!room) return;

  for (const ws of room) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(message);
    }
  }
}

/**
 * Broadcast a message to both players AND spectators of a match.
 */
export function broadcastToMatchAndSpectators(
  matchId: string,
  data: Record<string, unknown>
): void {
  broadcastToMatch(matchId, data);
  broadcastToSpectators(matchId, data);
}

export function registerUserConnection(
  address: string,
  ws: WebSocket
): void {
  if (!userConnections.has(address)) {
    userConnections.set(address, new Set());
  }
  userConnections.get(address)!.add(ws);
}

export function unregisterUserConnection(
  address: string,
  ws: WebSocket
): void {
  const conns = userConnections.get(address);
  if (conns) {
    conns.delete(ws);
    if (conns.size === 0) userConnections.delete(address);
  }
}

/**
 * Broadcast a message to all clients in a match room.
 * Special key "__all_active__" broadcasts to ALL match rooms.
 */
export function broadcastToMatch(
  matchId: string,
  data: Record<string, unknown>
): void {
  const message = JSON.stringify(data);

  if (matchId === "__all_active__") {
    for (const [, room] of matchRooms) {
      for (const ws of room) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(message);
        }
      }
    }
    // Also broadcast to all spectator rooms (e.g. price updates).
    for (const [, room] of spectatorRooms) {
      for (const ws of room) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(message);
        }
      }
    }
    return;
  }

  const room = matchRooms.get(matchId);
  if (!room) return;

  for (const ws of room) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(message);
    }
  }
}

/**
 * Broadcast a message to a specific user's connections.
 */
export function broadcastToUser(
  address: string,
  data: Record<string, unknown>
): void {
  const conns = userConnections.get(address);
  if (!conns) return;

  const message = JSON.stringify(data);
  for (const ws of conns) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(message);
    }
  }
}

/**
 * Broadcast a message to ALL connected WebSocket clients.
 */
export function broadcastToAll(data: Record<string, unknown>): void {
  const message = JSON.stringify(data);
  for (const [, conns] of userConnections) {
    for (const ws of conns) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(message);
      }
    }
  }
}

/**
 * Check if a user currently has any active WebSocket connections.
 */
export function isUserConnected(address: string): boolean {
  const conns = userConnections.get(address);
  return !!conns && conns.size > 0;
}

/**
 * Get the number of active WebSocket connections for a user.
 */
export function getUserConnectionCount(address: string): number {
  return userConnections.get(address)?.size ?? 0;
}

/**
 * Get the number of unique online players (distinct wallet addresses with open WS).
 */
export function getOnlinePlayerCount(): number {
  return userConnections.size;
}

/**
 * Get the number of active match rooms.
 */
export function getActiveRoomCount(): number {
  return matchRooms.size;
}

/**
 * Get all active match room IDs.
 */
export function getActiveMatchIds(): string[] {
  return Array.from(matchRooms.keys());
}

// ── Per-match price snapshots for settlement consistency ──
// Settlement uses these instead of live prices so that the server-computed
// ROI matches what clients displayed at match end.

const matchLastPrices = new Map<string, { btc: number; eth: number; sol: number }>();

/** Frozen matches won't accept new price updates — their snapshot is locked. */
const frozenMatches = new Set<string>();

export function storeMatchPrices(matchId: string, prices: { btc: number; eth: number; sol: number }): void {
  if (frozenMatches.has(matchId)) return; // Don't overwrite frozen prices.
  matchLastPrices.set(matchId, { ...prices });
}

/** Freeze prices for a match so subsequent broadcasts don't overwrite them. */
export function freezeMatchPrices(matchId: string): void {
  frozenMatches.add(matchId);
}

export function getMatchLastPrices(matchId: string): { btc: number; eth: number; sol: number } | undefined {
  return matchLastPrices.get(matchId);
}

export function clearMatchPrices(matchId: string): void {
  matchLastPrices.delete(matchId);
  frozenMatches.delete(matchId);
}
