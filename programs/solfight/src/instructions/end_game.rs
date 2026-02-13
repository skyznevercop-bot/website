use anchor_lang::prelude::*;

use crate::errors::SolFightError;
use crate::events::GameSettled;
use crate::state::{Game, GameStatus, Platform, PlayerProfile};

#[derive(Accounts)]
pub struct EndGame<'info> {
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
        constraint = game.status == GameStatus::Active @ SolFightError::GameNotActive,
    )]
    pub game: Account<'info, Game>,

    #[account(
        mut,
        seeds = [PlayerProfile::SEED, game.player_one.as_ref()],
        bump = player_one_profile.bump,
    )]
    pub player_one_profile: Account<'info, PlayerProfile>,

    #[account(
        mut,
        seeds = [PlayerProfile::SEED, game.player_two.as_ref()],
        bump = player_two_profile.bump,
    )]
    pub player_two_profile: Account<'info, PlayerProfile>,

    /// Platform authority (backend signer).
    pub authority: Signer<'info>,
}

pub fn handler(
    ctx: Context<EndGame>,
    winner_key: Option<Pubkey>,
    player_one_pnl: i64,
    player_two_pnl: i64,
    is_forfeit: bool,
) -> Result<()> {
    let game = &mut ctx.accounts.game;

    // Validate winner if provided.
    if let Some(ref winner) = winner_key {
        require!(
            *winner == game.player_one || *winner == game.player_two,
            SolFightError::NotAPlayer
        );
    }

    let clock = Clock::get()?;
    let is_tie = winner_key.is_none() && !is_forfeit;

    // Set game status based on outcome.
    if is_tie {
        game.status = GameStatus::Tied;
    } else if is_forfeit {
        game.status = GameStatus::Forfeited;
    } else {
        game.status = GameStatus::Settled;
    }

    game.winner = winner_key;
    game.player_one_pnl = player_one_pnl;
    game.player_two_pnl = player_two_pnl;
    game.settled_at = clock.unix_timestamp;

    // Update player profiles.
    let p1 = &mut ctx.accounts.player_one_profile;
    let p2 = &mut ctx.accounts.player_two_profile;

    p1.games_played += 1;
    p2.games_played += 1;

    p1.total_pnl = p1
        .total_pnl
        .checked_add(player_one_pnl)
        .ok_or(SolFightError::MathOverflow)?;
    p2.total_pnl = p2
        .total_pnl
        .checked_add(player_two_pnl)
        .ok_or(SolFightError::MathOverflow)?;

    if is_tie {
        // Tie: both get a tie, streaks reset.
        p1.ties += 1;
        p1.current_streak = 0;
        p2.ties += 1;
        p2.current_streak = 0;
    } else if let Some(ref winner) = winner_key {
        // Win/loss update.
        if *winner == game.player_one {
            p1.wins += 1;
            p1.current_streak += 1;
            p2.losses += 1;
            p2.current_streak = 0;
        } else {
            p2.wins += 1;
            p2.current_streak += 1;
            p1.losses += 1;
            p1.current_streak = 0;
        }
    }

    emit!(GameSettled {
        game_id: game.game_id,
        winner: winner_key,
        player_one_pnl,
        player_two_pnl,
        is_tie,
        is_forfeit,
    });

    Ok(())
}
