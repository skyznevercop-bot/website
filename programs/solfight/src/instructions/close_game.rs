use anchor_lang::prelude::*;
use anchor_spl::token::{Token, TokenAccount};

use crate::errors::SolFightError;
use crate::state::{Game, GameStatus, Platform};

#[derive(Accounts)]
pub struct CloseGame<'info> {
    #[account(
        seeds = [Platform::SEED],
        bump = platform.bump,
        constraint = platform.authority == authority.key() @ SolFightError::Unauthorized,
    )]
    pub platform: Account<'info, Platform>,

    #[account(
        mut,
        seeds = [Game::SEED, game.game_id.to_le_bytes().as_ref()],
        bump = game.bump,
        close = authority,
    )]
    pub game: Account<'info, Game>,

    /// Escrow token account — must be empty before closing the game.
    #[account(
        mut,
        constraint = escrow_token_account.key() == game.escrow_token_account,
        constraint = escrow_token_account.amount == 0 @ SolFightError::EscrowNotEmpty,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    /// Authority receives the reclaimed rent.
    #[account(mut)]
    pub authority: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<CloseGame>) -> Result<()> {
    let game = &ctx.accounts.game;

    // Only allow closing games that are fully resolved.
    require!(
        game.status == GameStatus::Settled
            || game.status == GameStatus::Forfeited
            || game.status == GameStatus::Tied
            || game.status == GameStatus::Cancelled,
        SolFightError::GameNotSettled
    );

    // Also close the escrow token account, returning its rent to authority.
    let game_id_bytes = game.game_id.to_le_bytes();
    let bump_bytes = [game.bump];
    let signer_seeds: &[&[&[u8]]] = &[&[Game::SEED, &game_id_bytes, &bump_bytes]];

    anchor_spl::token::close_account(CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        anchor_spl::token::CloseAccount {
            account: ctx.accounts.escrow_token_account.to_account_info(),
            destination: ctx.accounts.authority.to_account_info(),
            authority: ctx.accounts.game.to_account_info(),
        },
        signer_seeds,
    ))?;

    msg!(
        "Game {} closed — rent reclaimed by authority",
        game.game_id
    );

    Ok(())
}
