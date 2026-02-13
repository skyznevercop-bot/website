import admin from "firebase-admin";
import { config } from "../config";

// Initialize Firebase Admin SDK.
if (!admin.apps.length) {
  if (config.firebaseServiceAccountPath) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const serviceAccount = require(config.firebaseServiceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: config.firebaseDatabaseUrl,
    });
  } else {
    // Fallback: use application default credentials (e.g. in Cloud Run).
    admin.initializeApp({
      databaseURL: config.firebaseDatabaseUrl,
    });
  }
}

/** Firebase Realtime Database reference. */
export const db = admin.database();

// ── Helper references ─────────────────────────────────────────────

export const usersRef = db.ref("solfight/users");
export const matchesRef = db.ref("solfight/matches");
export const positionsRef = db.ref("solfight/positions");
export const queuesRef = db.ref("solfight/queues");
export const referralsRef = db.ref("solfight/referrals");
export const clansRef = db.ref("solfight/clans");
export const noncesRef = db.ref("solfight/nonces");

// ── User helpers ──────────────────────────────────────────────────

export interface DbUser {
  gamerTag?: string;
  wins: number;
  losses: number;
  ties: number;
  totalPnl: number;
  currentStreak: number;
  gamesPlayed: number;
  createdAt: number;
}

export async function getUser(address: string): Promise<DbUser | null> {
  const snap = await usersRef.child(address).once("value");
  return snap.exists() ? (snap.val() as DbUser) : null;
}

export async function getOrCreateUser(address: string): Promise<DbUser> {
  const existing = await getUser(address);
  if (existing) return existing;

  const newUser: DbUser = {
    wins: 0,
    losses: 0,
    ties: 0,
    totalPnl: 0,
    currentStreak: 0,
    gamesPlayed: 0,
    createdAt: Date.now(),
  };
  await usersRef.child(address).set(newUser);
  return newUser;
}

export async function updateUser(
  address: string,
  data: Partial<DbUser>
): Promise<void> {
  await usersRef.child(address).update(data);
}

// ── Match helpers ─────────────────────────────────────────────────

export interface DbMatch {
  player1: string;
  player2: string;
  timeframe: string;
  betAmount: number;
  status: "pending" | "active" | "completed" | "cancelled" | "forfeited" | "tied";
  winner?: string;
  player1Roi?: number;
  player2Roi?: number;
  escrowSignature?: string;
  startTime?: number;
  endTime?: number;
  settledAt?: number;
  onChainGameId?: number;
}

export async function createMatch(data: DbMatch): Promise<string> {
  const ref = matchesRef.push();
  await ref.set(data);
  return ref.key!;
}

export async function getMatch(matchId: string): Promise<DbMatch | null> {
  const snap = await matchesRef.child(matchId).once("value");
  return snap.exists() ? (snap.val() as DbMatch) : null;
}

export async function updateMatch(
  matchId: string,
  data: Partial<DbMatch>
): Promise<void> {
  await matchesRef.child(matchId).update(data);
}

// ── Position helpers ──────────────────────────────────────────────

export interface DbPosition {
  playerAddress: string;
  assetSymbol: string;
  isLong: boolean;
  entryPrice: number;
  exitPrice?: number;
  size: number;
  leverage: number;
  pnl?: number;
  openedAt: number;
  closedAt?: number;
  closeReason?: string;
}

export async function createPosition(
  matchId: string,
  data: DbPosition
): Promise<string> {
  const ref = positionsRef.child(matchId).push();
  await ref.set(data);
  return ref.key!;
}

export async function getPositions(
  matchId: string,
  playerAddress?: string
): Promise<Array<DbPosition & { id: string }>> {
  const snap = await positionsRef.child(matchId).once("value");
  if (!snap.exists()) return [];

  const positions: Array<DbPosition & { id: string }> = [];
  snap.forEach((child) => {
    const pos = child.val() as DbPosition;
    if (!playerAddress || pos.playerAddress === playerAddress) {
      positions.push({ ...pos, id: child.key! });
    }
  });
  return positions;
}

export async function updatePosition(
  matchId: string,
  positionId: string,
  data: Partial<DbPosition>
): Promise<void> {
  await positionsRef.child(matchId).child(positionId).update(data);
}

// ── Clan helpers ──────────────────────────────────────────────────

export interface DbClan {
  name: string;
  tag: string;
  description?: string;
  leaderAddress: string;
  maxMembers: number;
  totalWins: number;
  totalLosses: number;
  trophies: number;
  createdAt: number;
}

export interface DbClanMember {
  role: "LEADER" | "CO_LEADER" | "ELDER" | "MEMBER";
  joinedAt: number;
}
