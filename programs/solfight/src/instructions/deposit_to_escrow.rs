use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use crate::errors::SolFightError;
use crate::events::{GameStarted, PlayerDeposited};
use crate::state::{Game, GameStatus};

#[derive(Accounts)]
pub struct DepositToEscrow<'info> {
    #[account(
        mut,
        seeds = [Game::SEED, game.game_id.to_le_bytes().as_ref()],
        bump = game.bump,
        constraint = game.status == GameStatus::Pending @ SolFightError::GameNotPending,
    )]
    pub game: Account<'info, Game>,

    /// Player's USDC token account.
    #[account(
        mut,
        constraint = player_token_account.owner == player.key(),
        constraint = player_token_account.mint == escrow_token_account.mint,
    )]
    pub player_token_account: Account<'info, TokenAccount>,

    /// Escrow token account owned by the game PDA.
    #[account(
        mut,
        constraint = escrow_token_account.key() == game.escrow_token_account,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    /// The depositing player.
    #[account(
        constraint = player.key() == game.player_one || player.key() == game.player_two @ SolFightError::NotAPlayer,
    )]
    pub player: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<DepositToEscrow>) -> Result<()> {
    let game = &mut ctx.accounts.game;
    let player_key = ctx.accounts.player.key();

    // Check if this player already deposited.
    let is_player_one = player_key == game.player_one;
    if is_player_one {
        require!(!game.player_one_deposited, SolFightError::AlreadyDeposited);
    } else {
        require!(!game.player_two_deposited, SolFightError::AlreadyDeposited);
    }

    // Transfer USDC from player to escrow.
    let transfer_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        Transfer {
            from: ctx.accounts.player_token_account.to_account_info(),
            to: ctx.accounts.escrow_token_account.to_account_info(),
            authority: ctx.accounts.player.to_account_info(),
        },
    );
    token::transfer(transfer_ctx, game.bet_amount)?;

    // Mark deposit.
    if is_player_one {
        game.player_one_deposited = true;
    } else {
        game.player_two_deposited = true;
    }

    emit!(PlayerDeposited {
        game_id: game.game_id,
        player: player_key,
        amount: game.bet_amount,
    });

    // If both deposited, activate the match.
    if game.player_one_deposited && game.player_two_deposited {
        let clock = Clock::get()?;
        game.status = GameStatus::Active;
        game.start_time = clock.unix_timestamp;
        game.end_time = clock
            .unix_timestamp
            .checked_add(game.timeframe_seconds as i64)
            .ok_or(SolFightError::MathOverflow)?;

        emit!(GameStarted {
            game_id: game.game_id,
            start_time: game.start_time,
            end_time: game.end_time,
        });
    }

    Ok(())
}
