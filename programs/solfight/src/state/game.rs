use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq, InitSpace)]
pub enum GameStatus {
    /// Waiting for both players to deposit.
    Pending,
    /// Both deposited — match in progress.
    Active,
    /// Winner determined, awaiting claim.
    Settled,
    /// Match was cancelled before completion.
    Cancelled,
}

#[account]
#[derive(InitSpace)]
pub struct Game {
    /// Sequential game identifier.
    pub game_id: u64,
    /// First player's wallet.
    pub player_one: Pubkey,
    /// Second player's wallet.
    pub player_two: Pubkey,
    /// Bet per player in USDC (6 decimals).
    pub bet_amount: u64,
    /// Match duration in seconds.
    pub timeframe_seconds: u32,
    /// PDA-owned token account holding the escrow.
    pub escrow_token_account: Pubkey,
    /// Current match status.
    pub status: GameStatus,
    /// Winner (None until settled).
    pub winner: Option<Pubkey>,
    /// Player one final PnL (basis points of bet).
    pub player_one_pnl: i64,
    /// Player two final PnL (basis points of bet).
    pub player_two_pnl: i64,
    /// Whether player one has deposited.
    pub player_one_deposited: bool,
    /// Whether player two has deposited.
    pub player_two_deposited: bool,
    /// Unix timestamp when match starts.
    pub start_time: i64,
    /// Unix timestamp when match ends.
    pub end_time: i64,
    /// Unix timestamp when settled (0 if not yet).
    pub settled_at: i64,
    /// PDA bump seed.
    pub bump: u8,
}

impl Game {
    pub const SEED: &'static [u8] = b"game";
}
