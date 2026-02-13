import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import nacl from "tweetnacl";
import bs58 from "bs58";
import { config } from "../config";
import { noncesRef, getOrCreateUser } from "../services/firebase";

export interface AuthRequest extends Request {
  userAddress?: string;
}

/** JWT verification middleware. */
export function requireAuth(
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing authorization token" });
    return;
  }

  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, config.jwtSecret) as {
      address: string;
    };
    req.userAddress = payload.address;
    next();
  } catch {
    res.status(401).json({ error: "Invalid or expired token" });
  }
}

/** Generate a random nonce for wallet signature verification. */
export function generateNonce(): string {
  const bytes = nacl.randomBytes(32);
  return bs58.encode(bytes);
}

/** Verify an ed25519 wallet signature against the expected message. */
export function verifyWalletSignature(
  address: string,
  signature: string,
  message: string
): boolean {
  try {
    const publicKey = bs58.decode(address);
    const signatureBytes = bs58.decode(signature);
    const messageBytes = new TextEncoder().encode(message);
    return nacl.sign.detached.verify(messageBytes, signatureBytes, publicKey);
  } catch {
    return false;
  }
}

/** Issue a JWT for the given wallet address. */
export function issueToken(address: string): string {
  return jwt.sign({ address }, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn as string,
  } as jwt.SignOptions);
}

/** Get or create user nonce (stored in Firebase). */
export async function getOrCreateNonce(address: string): Promise<string> {
  const nonce = generateNonce();
  await noncesRef.child(address).set(nonce);
  await getOrCreateUser(address);
  return nonce;
}
