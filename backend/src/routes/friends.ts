import { Router } from "express";
import { requireAuth, AuthRequest } from "../middleware/auth";
import { friendsRef, getUser } from "../services/firebase";
import { broadcastToUser } from "../ws/handler";
import { isValidSolanaAddress } from "../utils/validation";

const router = Router();

// ── GET /api/friends — List all accepted friends with stats ──────────

router.get("/", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const snap = await friendsRef.child(address).once("value");

    if (!snap.exists()) {
      res.json({ friends: [] });
      return;
    }

    const friendEntries = snap.val() as Record<
      string,
      { status: string; createdAt: number; acceptedAt?: number }
    >;

    const friends = await Promise.all(
      Object.entries(friendEntries)
        .filter(([, v]) => v.status === "accepted")
        .map(async ([friendAddr, meta]) => {
          const u = await getUser(friendAddr);
          return {
            address: friendAddr,
            gamerTag: u?.gamerTag || friendAddr.slice(0, 8),
            wins: u?.wins || 0,
            losses: u?.losses || 0,
            ties: u?.ties || 0,
            totalPnl: u?.totalPnl || 0,
            currentStreak: u?.currentStreak || 0,
            gamesPlayed: u?.gamesPlayed || 0,
            connectedSince: new Date(meta.acceptedAt || meta.createdAt).toISOString(),
          };
        })
    );

    res.json({ friends });
  } catch (err) {
    console.error("[Friends] GET / error:", err);
    res.status(500).json({ error: "Failed to fetch friends" });
  }
});

// ── GET /api/friends/requests — List pending incoming requests ───────

router.get("/requests", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const snap = await friendsRef.child(address).once("value");

    if (!snap.exists()) {
      res.json({ requests: [] });
      return;
    }

    const entries = snap.val() as Record<
      string,
      { status: string; createdAt: number }
    >;

    const requests = await Promise.all(
      Object.entries(entries)
        .filter(([, v]) => v.status === "pending_received")
        .map(async ([fromAddr, meta]) => {
          const u = await getUser(fromAddr);
          return {
            fromAddress: fromAddr,
            fromGamerTag: u?.gamerTag || fromAddr.slice(0, 8),
            createdAt: new Date(meta.createdAt).toISOString(),
          };
        })
    );

    res.json({ requests });
  } catch (err) {
    console.error("[Friends] GET /requests error:", err);
    res.status(500).json({ error: "Failed to fetch requests" });
  }
});

// ── POST /api/friends/add — Send a friend request ───────────────────

router.post("/add", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const { address: friendAddress } = req.body;

    if (!isValidSolanaAddress(friendAddress)) {
      res.status(400).json({ error: "Valid friend wallet address is required" });
      return;
    }

    if (friendAddress === address) {
      res.status(400).json({ error: "Cannot add yourself" });
      return;
    }

    // Check if relationship already exists.
    const existingSnap = await friendsRef
      .child(address)
      .child(friendAddress)
      .once("value");
    if (existingSnap.exists()) {
      const status = existingSnap.val().status;
      if (status === "accepted") {
        res.status(400).json({ error: "Already friends" });
        return;
      }
      if (status === "pending_sent") {
        res.status(400).json({ error: "Request already sent" });
        return;
      }
      if (status === "pending_received") {
        // They already sent us a request — auto-accept.
        const now = Date.now();
        await Promise.all([
          friendsRef.child(address).child(friendAddress).update({
            status: "accepted",
            acceptedAt: now,
          }),
          friendsRef.child(friendAddress).child(address).update({
            status: "accepted",
            acceptedAt: now,
          }),
        ]);
        res.json({ status: "accepted", message: "Friend request accepted" });
        return;
      }
    }

    const now = Date.now();

    // Store both sides.
    await Promise.all([
      friendsRef.child(address).child(friendAddress).set({
        status: "pending_sent",
        createdAt: now,
      }),
      friendsRef.child(friendAddress).child(address).set({
        status: "pending_received",
        createdAt: now,
      }),
    ]);

    // Notify the recipient via WebSocket.
    const sender = await getUser(address);
    broadcastToUser(friendAddress, {
      type: "friend_request",
      from: address,
      fromGamerTag: sender?.gamerTag || address.slice(0, 8),
    });

    res.json({ status: "pending", message: "Friend request sent" });
  } catch (err) {
    console.error("[Friends] POST /add error:", err);
    res.status(500).json({ error: "Failed to send friend request" });
  }
});

// ── POST /api/friends/accept — Accept a friend request ──────────────

router.post("/accept", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const { address: friendAddress } = req.body;

    if (!isValidSolanaAddress(friendAddress)) {
      res.status(400).json({ error: "Valid friend wallet address is required" });
      return;
    }

    // Verify pending request exists.
    const snap = await friendsRef
      .child(address)
      .child(friendAddress)
      .once("value");
    if (!snap.exists() || snap.val().status !== "pending_received") {
      res.status(400).json({ error: "No pending request from this address" });
      return;
    }

    const now = Date.now();
    await Promise.all([
      friendsRef.child(address).child(friendAddress).update({
        status: "accepted",
        acceptedAt: now,
      }),
      friendsRef.child(friendAddress).child(address).update({
        status: "accepted",
        acceptedAt: now,
      }),
    ]);

    // Notify the sender.
    const acceptor = await getUser(address);
    broadcastToUser(friendAddress, {
      type: "friend_accepted",
      from: address,
      fromGamerTag: acceptor?.gamerTag || address.slice(0, 8),
    });

    res.json({ status: "accepted" });
  } catch (err) {
    console.error("[Friends] POST /accept error:", err);
    res.status(500).json({ error: "Failed to accept request" });
  }
});

// ── DELETE /api/friends/:address — Remove friend or decline request ──

router.delete("/:friendAddress", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const friendAddress = req.params.friendAddress;

    // Remove both sides.
    await Promise.all([
      friendsRef.child(address).child(friendAddress).remove(),
      friendsRef.child(friendAddress).child(address).remove(),
    ]);

    res.json({ status: "removed" });
  } catch (err) {
    console.error("[Friends] DELETE error:", err);
    res.status(500).json({ error: "Failed to remove friend" });
  }
});

export default router;
