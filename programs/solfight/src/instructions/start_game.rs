use anchor_lang::prelude::*;
use anchor_spl::associated_token::AssociatedToken;
use anchor_spl::token::{Mint, Token, TokenAccount};

use crate::errors::SolFightError;
use crate::events::GameCreated;
use crate::state::{Game, GameStatus, Platform};

#[derive(Accounts)]
pub struct StartGame<'info> {
    #[account(
        mut,
        seeds = [Platform::SEED],
        bump = platform.bump,
        has_one = authority,
    )]
    pub platform: Account<'info, Platform>,

    #[account(
        init,
        payer = authority,
        space = 8 + Game::INIT_SPACE,
        seeds = [Game::SEED, (platform.total_games + 1).to_le_bytes().as_ref()],
        bump,
    )]
    pub game: Account<'info, Game>,

    /// The escrow token account owned by the game PDA.
    #[account(
        init,
        payer = authority,
        associated_token::mint = usdc_mint,
        associated_token::authority = game,
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,

    /// USDC mint (devnet or mainnet).
    pub usdc_mint: Account<'info, Mint>,

    /// Platform authority (backend signer).
    #[account(mut)]
    pub authority: Signer<'info>,

    /// CHECK: Player one wallet address.
    pub player_one: UncheckedAccount<'info>,

    /// CHECK: Player two wallet address.
    pub player_two: UncheckedAccount<'info>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
}

pub fn handler(
    ctx: Context<StartGame>,
    bet_amount: u64,
    timeframe_seconds: u32,
) -> Result<()> {
    require!(bet_amount > 0, SolFightError::InvalidBetAmount);

    let platform = &mut ctx.accounts.platform;
    let game_id = platform.total_games + 1;
    platform.total_games = game_id;
    platform.total_volume = platform
        .total_volume
        .checked_add(bet_amount.checked_mul(2).ok_or(SolFightError::MathOverflow)?)
        .ok_or(SolFightError::MathOverflow)?;

    let game = &mut ctx.accounts.game;
    game.game_id = game_id;
    game.player_one = ctx.accounts.player_one.key();
    game.player_two = ctx.accounts.player_two.key();
    game.bet_amount = bet_amount;
    game.timeframe_seconds = timeframe_seconds;
    game.escrow_token_account = ctx.accounts.escrow_token_account.key();
    game.status = GameStatus::Pending;
    game.winner = None;
    game.player_one_pnl = 0;
    game.player_two_pnl = 0;
    game.player_one_deposited = false;
    game.player_two_deposited = false;
    game.start_time = 0;
    game.end_time = 0;
    game.settled_at = 0;
    game.bump = ctx.bumps.game;

    emit!(GameCreated {
        game_id,
        player_one: ctx.accounts.player_one.key(),
        player_two: ctx.accounts.player_two.key(),
        bet_amount,
        timeframe_seconds,
    });

    Ok(())
}
