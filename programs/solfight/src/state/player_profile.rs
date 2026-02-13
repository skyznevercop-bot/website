use anchor_lang::prelude::*;

#[account]
#[derive(InitSpace)]
pub struct PlayerProfile {
    /// Wallet that owns this profile.
    pub authority: Pubkey,
    /// Display name (max 16 UTF-8 bytes).
    #[max_len(16)]
    pub gamer_tag: String,
    /// Current ELO rating (default 1200).
    pub elo_rating: u32,
    /// Total wins.
    pub wins: u32,
    /// Total losses.
    pub losses: u32,
    /// Cumulative PnL in USDC lamports (signed).
    pub total_pnl: i64,
    /// Current winning streak.
    pub current_streak: u32,
    /// Total games played.
    pub games_played: u32,
    /// Unix timestamp of profile creation.
    pub created_at: i64,
    /// PDA bump seed.
    pub bump: u8,
}

impl PlayerProfile {
    pub const SEED: &'static [u8] = b"player";
}
