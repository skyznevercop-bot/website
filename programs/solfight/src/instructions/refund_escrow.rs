use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use crate::errors::SolFightError;
use crate::events::EscrowRefunded;
use crate::state::{Game, GameStatus};

#[derive(Accounts)]
pub struct RefundEscrow<'info> {
    #[account(
        mut,
        seeds = [Game::SEED, game.game_id.to_le_bytes().as_ref()],
        bump = game.bump,
        constraint = (game.status == GameStatus::Tied || game.status == GameStatus::Cancelled) @ SolFightError::NotRefundable,
    )]
    pub game: Account<'info, Game>,

    /// Escrow token account owned by the game PDA.
    #[account(
        mut,
        constraint = escrow_token_account.key() == game.escrow_token_account,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    /// Player one's USDC token account.
    #[account(
        mut,
        constraint = player_one_token_account.owner == game.player_one,
    )]
    pub player_one_token_account: Account<'info, TokenAccount>,

    /// Player two's USDC token account.
    #[account(
        mut,
        constraint = player_two_token_account.owner == game.player_two,
    )]
    pub player_two_token_account: Account<'info, TokenAccount>,

    /// Anyone can call refund (permissionless).
    pub caller: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<RefundEscrow>) -> Result<()> {
    let game = &ctx.accounts.game;
    let refund_amount = game.bet_amount;

    // Build PDA signer seeds for the game account.
    let game_id_bytes = game.game_id.to_le_bytes();
    let bump_bytes = [game.bump];
    let signer_seeds: &[&[&[u8]]] = &[&[Game::SEED, &game_id_bytes, &bump_bytes]];

    // Refund player one (if they deposited).
    if game.player_one_deposited {
        let transfer_p1 = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.escrow_token_account.to_account_info(),
                to: ctx.accounts.player_one_token_account.to_account_info(),
                authority: ctx.accounts.game.to_account_info(),
            },
            signer_seeds,
        );
        token::transfer(transfer_p1, refund_amount)?;
    }

    // Refund player two (if they deposited).
    if game.player_two_deposited {
        let transfer_p2 = CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.escrow_token_account.to_account_info(),
                to: ctx.accounts.player_two_token_account.to_account_info(),
                authority: ctx.accounts.game.to_account_info(),
            },
            signer_seeds,
        );
        token::transfer(transfer_p2, refund_amount)?;
    }

    emit!(EscrowRefunded {
        game_id: game.game_id,
        player_one: game.player_one,
        player_two: game.player_two,
        refund_amount,
    });

    Ok(())
}
