use anchor_lang::prelude::*;

pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("So1F1gHTxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

#[program]
pub mod solfight {
    use super::*;

    /// One-time platform initialization.
    pub fn initialize_platform(ctx: Context<InitializePlatform>, fee_bps: u16) -> Result<()> {
        instructions::initialize_platform::handler(ctx, fee_bps)
    }

    /// Create a player profile PDA.
    pub fn create_profile(ctx: Context<CreateProfile>, gamer_tag: String) -> Result<()> {
        instructions::create_profile::handler(ctx, gamer_tag)
    }

    /// Backend creates a new game between two matched players.
    pub fn start_game(
        ctx: Context<StartGame>,
        bet_amount: u64,
        timeframe_seconds: u32,
    ) -> Result<()> {
        instructions::start_game::handler(ctx, bet_amount, timeframe_seconds)
    }

    /// Player deposits their bet into the game escrow.
    pub fn deposit_to_escrow(ctx: Context<DepositToEscrow>) -> Result<()> {
        instructions::deposit_to_escrow::handler(ctx)
    }

    /// Backend settles the game with the winner and PnL data.
    /// Pass `winner = None` for ties, `is_forfeit = true` for disconnect forfeits.
    pub fn end_game(
        ctx: Context<EndGame>,
        winner: Option<Pubkey>,
        player_one_pnl: i64,
        player_two_pnl: i64,
        is_forfeit: bool,
    ) -> Result<()> {
        instructions::end_game::handler(ctx, winner, player_one_pnl, player_two_pnl, is_forfeit)
    }

    /// Winner claims their payout from the escrow (Settled or Forfeited games).
    pub fn claim_winnings(ctx: Context<ClaimWinnings>) -> Result<()> {
        instructions::claim_winnings::handler(ctx)
    }

    /// Refund escrow to both players (Tied or Cancelled games).
    pub fn refund_escrow(ctx: Context<RefundEscrow>) -> Result<()> {
        instructions::refund_escrow::handler(ctx)
    }
}
