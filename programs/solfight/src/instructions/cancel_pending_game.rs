use anchor_lang::prelude::*;

use crate::errors::SolFightError;
use crate::state::{Game, GameStatus, Platform};

#[derive(Accounts)]
pub struct CancelPendingGame<'info> {
    #[account(
        seeds = [Platform::SEED],
        bump = platform.bump,
        has_one = authority,
    )]
    pub platform: Account<'info, Platform>,

    #[account(
        mut,
        seeds = [Game::SEED, game.game_id.to_le_bytes().as_ref()],
        bump = game.bump,
        constraint = game.status == GameStatus::Pending @ SolFightError::GameNotPending,
    )]
    pub game: Account<'info, Game>,

    /// Platform authority (backend signer).
    pub authority: Signer<'info>,
}

pub fn handler(ctx: Context<CancelPendingGame>) -> Result<()> {
    let game = &mut ctx.accounts.game;
    game.status = GameStatus::Cancelled;
    Ok(())
}
