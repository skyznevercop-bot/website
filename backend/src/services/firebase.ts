import admin from "firebase-admin";
import path from "path";
import fs from "fs";
import { config } from "../config";

// Initialize Firebase Admin SDK.
// Supports three credential modes:
// 1. FIREBASE_SERVICE_ACCOUNT_JSON env var (inline JSON string — for cloud deploys)
// 2. FIREBASE_SERVICE_ACCOUNT file path (for local dev)
// 3. Application default credentials (for GCP environments)
if (!admin.apps.length) {
  const inlineJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (inlineJson) {
    const serviceAccount = JSON.parse(inlineJson);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: config.firebaseDatabaseUrl,
    });
  } else if (config.firebaseServiceAccountPath) {
    const absPath = path.resolve(config.firebaseServiceAccountPath);
    if (fs.existsSync(absPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(absPath, "utf-8"));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: config.firebaseDatabaseUrl,
      });
    } else {
      console.warn(`[Firebase] Service account file not found at ${absPath}, using default credentials`);
      admin.initializeApp({ databaseURL: config.firebaseDatabaseUrl });
    }
  } else {
    admin.initializeApp({ databaseURL: config.firebaseDatabaseUrl });
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
  clanId?: string | null;
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
  duration: string;
  betAmount: number;
  status:
    | "pending"
    | "awaiting_deposits"
    | "active"
    | "completed"
    | "cancelled"
    | "forfeited"
    | "tied";
  winner?: string;
  player1Roi?: number;
  player2Roi?: number;

  // Deposit tracking
  player1DepositSignature?: string;
  player2DepositSignature?: string;
  player1DepositVerified?: boolean;
  player2DepositVerified?: boolean;
  depositDeadline?: number;

  // Payout tracking
  payoutSignature?: string;
  payoutAmount?: number;
  rakeAmount?: number;
  refundSignatures?: Record<string, string>;
  escrowState?:
    | "awaiting_deposits"
    | "deposits_received"
    | "payout_sent"
    | "refunded"
    | "partial_refund"
    | "refund_failed"
    | "settlement_pending";

  escrowSignature?: string;
  startTime?: number;
  endTime?: number;
  settledAt?: number;
  onChainGameId?: number;
  onChainSettled?: boolean;
  onChainRetries?: number;
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

export async function getMatchesByStatus(
  status: string
): Promise<Array<{ id: string; data: DbMatch }>> {
  const snap = await matchesRef
    .orderByChild("status")
    .equalTo(status)
    .once("value");
  const results: Array<{ id: string; data: DbMatch }> = [];
  if (snap.exists()) {
    snap.forEach((child) => {
      results.push({ id: child.key!, data: child.val() as DbMatch });
    });
  }
  return results;
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
