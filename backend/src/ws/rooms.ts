import WebSocket from "ws";

/** Map of matchId → set of connected WebSocket clients. */
const matchRooms = new Map<string, Set<WebSocket>>();

/** Map of userAddress → set of connected WebSocket clients. */
const userConnections = new Map<string, Set<WebSocket>>();

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
