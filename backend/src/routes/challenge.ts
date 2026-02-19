import { Router } from "express";
import { requireAuth, AuthRequest } from "../middleware/auth";
import {
  friendsRef,
  challengesRef,
  getUser,
  createMatch as createDbMatch,
  DbMatch,
} from "../services/firebase";
import { freezeForMatch, unfreezeBalance } from "../services/balance";
import { broadcastToUser } from "../ws/handler";
import { isUserConnected } from "../ws/rooms";

const router = Router();

const CHALLENGE_EXPIRY_MS = 5 * 60 * 1000; // 5 minutes

function parseDurationToSeconds(duration: string): number {
  const m = duration.match(/^(\d+)(m|h)$/);
  if (!m) return 5 * 60;
  const value = parseInt(m[1]);
  const unit = m[2];
  if (unit === "h") return value * 60 * 60;
  return value * 60;
}

// ── GET /api/challenge/pending — List pending challenges ─────────────

router.get("/pending", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const snap = await challengesRef
      .orderByChild("status")
      .equalTo("pending")
      .once("value");

    const sent: Array<Record<string, unknown>> = [];
    const received: Array<Record<string, unknown>> = [];

    if (snap.exists()) {
      const now = Date.now();
      snap.forEach((child) => {
        const c = child.val();
        // Skip expired (will be cleaned by settlement loop).
        if (c.expiresAt && c.expiresAt <= now) return;

        if (c.from === address) {
          sent.push({ id: child.key, ...c });
        } else if (c.to === address) {
          received.push({ id: child.key, ...c });
        }
      });
    }

    // Enrich with gamer tags.
    const enriched = async (
      list: Array<Record<string, unknown>>,
      tagField: string,
      addrField: string
    ) => {
      return Promise.all(
        list.map(async (c) => {
          const u = await getUser(c[addrField] as string);
          return {
            ...c,
            [tagField]: u?.gamerTag || (c[addrField] as string).slice(0, 8),
          };
        })
      );
    };

    res.json({
      sent: await enriched(sent, "toGamerTag", "to"),
      received: await enriched(received, "fromGamerTag", "from"),
    });
  } catch (err) {
    console.error("[Challenge] GET /pending error:", err);
    res.status(500).json({ error: "Failed to fetch challenges" });
  }
});

// ── POST /api/challenge/create — Create a challenge ──────────────────

router.post("/create", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const { toAddress, duration, bet } = req.body;

    if (!toAddress || typeof toAddress !== "string") {
      res.status(400).json({ error: "toAddress is required" });
      return;
    }
    if (!duration || typeof duration !== "string") {
      res.status(400).json({ error: "duration is required" });
      return;
    }
    if (typeof bet !== "number" || !Number.isFinite(bet) || bet < 0) {
      res.status(400).json({ error: "Valid bet amount is required" });
      return;
    }

    if (toAddress === address) {
      res.status(400).json({ error: "Cannot challenge yourself" });
      return;
    }

    // Verify friendship.
    const friendSnap = await friendsRef
      .child(address)
      .child(toAddress)
      .once("value");
    if (!friendSnap.exists() || friendSnap.val().status !== "accepted") {
      res.status(400).json({ error: "You can only challenge friends" });
      return;
    }

    // Freeze bet for challenger (if bet > 0).
    if (bet > 0) {
      const frozen = await freezeForMatch(address, bet);
      if (!frozen) {
        res.status(400).json({ error: "Insufficient balance" });
        return;
      }
    }

    const now = Date.now();
    const challengeData = {
      from: address,
      to: toAddress,
      duration,
      bet,
      status: "pending",
      createdAt: now,
      expiresAt: now + CHALLENGE_EXPIRY_MS,
    };

    const ref = challengesRef.push();
    await ref.set(challengeData);

    // Notify the challenged player.
    const sender = await getUser(address);
    broadcastToUser(toAddress, {
      type: "challenge_received",
      challengeId: ref.key,
      from: address,
      fromGamerTag: sender?.gamerTag || address.slice(0, 8),
      duration,
      bet,
      expiresAt: now + CHALLENGE_EXPIRY_MS,
    });

    res.json({
      id: ref.key,
      status: "pending",
      expiresAt: now + CHALLENGE_EXPIRY_MS,
    });
  } catch (err) {
    console.error("[Challenge] POST /create error:", err);
    res.status(500).json({ error: "Failed to create challenge" });
  }
});

// ── POST /api/challenge/:id/accept — Accept and start match ──────────

router.post("/:id/accept", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const challengeId = req.params.id;

    const snap = await challengesRef.child(challengeId).once("value");
    if (!snap.exists()) {
      res.status(404).json({ error: "Challenge not found" });
      return;
    }

    const challenge = snap.val();
    if (challenge.to !== address) {
      res.status(403).json({ error: "Not your challenge to accept" });
      return;
    }
    if (challenge.status !== "pending") {
      res.status(400).json({ error: `Challenge is ${challenge.status}` });
      return;
    }
    if (challenge.expiresAt && challenge.expiresAt <= Date.now()) {
      res.status(400).json({ error: "Challenge has expired" });
      return;
    }

    const bet = challenge.bet as number;
    const duration = challenge.duration as string;
    const player1 = challenge.from as string;
    const player2 = address;

    // Freeze bet for acceptor (if bet > 0).
    if (bet > 0) {
      const frozen = await freezeForMatch(player2, bet);
      if (!frozen) {
        res.status(400).json({ error: "Insufficient balance" });
        return;
      }
    }

    // Create the match — same as matchmaking.
    const durationSeconds = parseDurationToSeconds(duration);
    const now = Date.now();

    const matchData: DbMatch = {
      player1,
      player2,
      duration,
      betAmount: bet,
      status: "active",
      startTime: now,
      endTime: now + durationSeconds * 1000,
    };

    const matchId = await createDbMatch(matchData);

    // Update challenge.
    await challengesRef.child(challengeId).update({
      status: "matched",
      matchId,
    });

    // Broadcast match_found to both players.
    const [p1User, p2User] = await Promise.all([
      getUser(player1),
      getUser(player2),
    ]);

    const matchPayload = (opponent: string, oppTag: string) => ({
      type: "match_found",
      matchId,
      opponent: { address: opponent, gamerTag: oppTag },
      duration,
      durationSeconds,
      bet,
      startTime: now,
      endTime: now + durationSeconds * 1000,
    });

    broadcastToUser(player1, matchPayload(player2, p2User?.gamerTag || player2.slice(0, 8)));
    broadcastToUser(player2, matchPayload(player1, p1User?.gamerTag || player1.slice(0, 8)));

    console.log(
      `[Challenge] Match created from challenge: ${matchId} | ${player1.slice(0, 8)}… vs ${player2.slice(0, 8)}… | ${duration} | $${bet}`
    );

    res.json({ status: "matched", matchId });
  } catch (err) {
    console.error("[Challenge] POST /:id/accept error:", err);
    res.status(500).json({ error: "Failed to accept challenge" });
  }
});

// ── POST /api/challenge/:id/decline — Decline a challenge ────────────

router.post("/:id/decline", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const challengeId = req.params.id;

    const snap = await challengesRef.child(challengeId).once("value");
    if (!snap.exists()) {
      res.status(404).json({ error: "Challenge not found" });
      return;
    }

    const challenge = snap.val();
    if (challenge.to !== address) {
      res.status(403).json({ error: "Not your challenge to decline" });
      return;
    }
    if (challenge.status !== "pending") {
      res.status(400).json({ error: `Challenge is ${challenge.status}` });
      return;
    }

    // Unfreeze challenger's bet.
    const bet = challenge.bet as number;
    if (bet > 0) {
      await unfreezeBalance(challenge.from as string, bet);
    }

    await challengesRef.child(challengeId).update({ status: "declined" });

    // Notify challenger.
    broadcastToUser(challenge.from as string, {
      type: "challenge_declined",
      challengeId,
      by: address,
    });

    res.json({ status: "declined" });
  } catch (err) {
    console.error("[Challenge] POST /:id/decline error:", err);
    res.status(500).json({ error: "Failed to decline challenge" });
  }
});

/**
 * Expire stale challenges — called from the settlement loop.
 * Finds pending challenges past expiresAt and unfreezes the challenger's bet.
 */
export async function expireStaleChallenges(): Promise<void> {
  try {
    const snap = await challengesRef
      .orderByChild("status")
      .equalTo("pending")
      .once("value");

    if (!snap.exists()) return;

    const now = Date.now();
    const tasks: Promise<void>[] = [];

    snap.forEach((child) => {
      const c = child.val();
      if (c.expiresAt && c.expiresAt <= now) {
        tasks.push(
          (async () => {
            const bet = c.bet as number;
            if (bet > 0) {
              await unfreezeBalance(c.from as string, bet);
            }
            await challengesRef.child(child.key!).update({ status: "expired" });
            console.log(`[Challenge] Expired ${child.key!}`);
          })()
        );
      }
    });

    if (tasks.length > 0) await Promise.all(tasks);
  } catch (err) {
    console.error("[Challenge] Expiry check error:", err);
  }
}

export default router;
