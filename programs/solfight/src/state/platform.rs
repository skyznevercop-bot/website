use anchor_lang::prelude::*;

#[account]
#[derive(InitSpace)]
pub struct Platform {
    /// Admin who can update platform settings.
    pub authority: Pubkey,
    /// Fee in basis points (100 = 1%).
    pub fee_bps: u16,
    /// Treasury wallet that receives fees.
    pub treasury: Pubkey,
    /// Running count of games created.
    pub total_games: u64,
    /// Cumulative bet volume in USDC lamports.
    pub total_volume: u64,
    /// PDA bump seed.
    pub bump: u8,
}

impl Platform {
    pub const SEED: &'static [u8] = b"platform";
}
