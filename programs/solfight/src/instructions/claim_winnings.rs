use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use crate::errors::SolFightError;
use crate::events::WinningsClaimed;
use crate::state::{Game, GameStatus, Platform};

#[derive(Accounts)]
pub struct ClaimWinnings<'info> {
    #[account(
        seeds = [Platform::SEED],
        bump = platform.bump,
    )]
    pub platform: Account<'info, Platform>,

    #[account(
        mut,
        seeds = [Game::SEED, game.game_id.to_le_bytes().as_ref()],
        bump = game.bump,
        constraint = (game.status == GameStatus::Settled || game.status == GameStatus::Forfeited) @ SolFightError::NotClaimable,
        constraint = game.winner == Some(winner.key()) @ SolFightError::NotWinner,
    )]
    pub game: Account<'info, Game>,

    /// Escrow token account owned by the game PDA.
    #[account(
        mut,
        constraint = escrow_token_account.key() == game.escrow_token_account,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    /// Winner's USDC token account.
    #[account(
        mut,
        constraint = winner_token_account.owner == winner.key(),
    )]
    pub winner_token_account: Account<'info, TokenAccount>,

    /// Treasury USDC token account for fees.
    #[account(
        mut,
        constraint = treasury_token_account.owner == platform.treasury,
    )]
    pub treasury_token_account: Account<'info, TokenAccount>,

    /// The winner (permissionless claim).
    pub winner: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<ClaimWinnings>) -> Result<()> {
    let game = &ctx.accounts.game;
    let platform = &ctx.accounts.platform;

    let total_pot = game
        .bet_amount
        .checked_mul(2)
        .ok_or(SolFightError::MathOverflow)?;

    let fee = total_pot
        .checked_mul(platform.fee_bps as u64)
        .ok_or(SolFightError::MathOverflow)?
        .checked_div(10_000)
        .ok_or(SolFightError::MathOverflow)?;

    let payout = total_pot
        .checked_sub(fee)
        .ok_or(SolFightError::MathOverflow)?;

    // Build PDA signer seeds for the game account.
    let game_id_bytes = game.game_id.to_le_bytes();
    let bump_bytes = [game.bump];
    let signer_seeds: &[&[&[u8]]] = &[&[Game::SEED, &game_id_bytes, &bump_bytes]];

    // Transfer payout to winner.
    let transfer_to_winner = CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        Transfer {
            from: ctx.accounts.escrow_token_account.to_account_info(),
            to: ctx.accounts.winner_token_account.to_account_info(),
            authority: ctx.accounts.game.to_account_info(),
        },
        signer_seeds,
    );
    token::transfer(transfer_to_winner, payout)?;

    // Transfer fee to treasury.
    if fee > 0 {
        let transfer_fee = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.escrow_token_account.to_account_info(),
                to: ctx.accounts.treasury_token_account.to_account_info(),
                authority: ctx.accounts.game.to_account_info(),
            },
            signer_seeds,
        );
        token::transfer(transfer_fee, fee)?;
    }

    emit!(WinningsClaimed {
        game_id: game.game_id,
        winner: ctx.accounts.winner.key(),
        payout,
        fee,
    });

    Ok(())
}
