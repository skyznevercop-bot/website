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
    winner_key: Pubkey,
    player_one_pnl: i64,
    player_two_pnl: i64,
) -> Result<()> {
    let game = &mut ctx.accounts.game;

    require!(
        winner_key == game.player_one || winner_key == game.player_two,
        SolFightError::NotAPlayer
    );

    let clock = Clock::get()?;

    game.status = GameStatus::Settled;
    game.winner = Some(winner_key);
    game.player_one_pnl = player_one_pnl;
    game.player_two_pnl = player_two_pnl;
    game.settled_at = clock.unix_timestamp;

    // Update ELO ratings.
    let p1 = &mut ctx.accounts.player_one_profile;
    let p2 = &mut ctx.accounts.player_two_profile;

    let (new_elo_winner, new_elo_loser) = calculate_elo(
        if winner_key == game.player_one {
            p1.elo_rating
        } else {
            p2.elo_rating
        },
        if winner_key == game.player_one {
            p2.elo_rating
        } else {
            p1.elo_rating
        },
        if winner_key == game.player_one {
            p1.games_played
        } else {
            p2.games_played
        },
        if winner_key == game.player_one {
            p2.games_played
        } else {
            p1.games_played
        },
    );

    // Update player one stats.
    p1.games_played += 1;
    p1.total_pnl = p1
        .total_pnl
        .checked_add(player_one_pnl)
        .ok_or(SolFightError::MathOverflow)?;

    if winner_key == game.player_one {
        p1.wins += 1;
        p1.current_streak += 1;
        p1.elo_rating = new_elo_winner;
    } else {
        p1.losses += 1;
        p1.current_streak = 0;
        p1.elo_rating = new_elo_loser;
    }

    // Update player two stats.
    p2.games_played += 1;
    p2.total_pnl = p2
        .total_pnl
        .checked_add(player_two_pnl)
        .ok_or(SolFightError::MathOverflow)?;

    if winner_key == game.player_two {
        p2.wins += 1;
        p2.current_streak += 1;
        p2.elo_rating = new_elo_winner;
    } else {
        p2.losses += 1;
        p2.current_streak = 0;
        p2.elo_rating = new_elo_loser;
    }

    emit!(GameSettled {
        game_id: game.game_id,
        winner: winner_key,
        player_one_pnl,
        player_two_pnl,
        winner_new_elo: new_elo_winner,
        loser_new_elo: new_elo_loser,
    });

    Ok(())
}

/// Classic ELO calculation with dynamic K-factor.
fn calculate_elo(
    winner_elo: u32,
    loser_elo: u32,
    winner_games: u32,
    loser_games: u32,
) -> (u32, u32) {
    let k_winner: f64 = if winner_games < 30 { 40.0 } else { 32.0 };
    let k_loser: f64 = if loser_games < 30 { 40.0 } else { 32.0 };

    let expected_winner =
        1.0 / (1.0 + 10.0_f64.powf((loser_elo as f64 - winner_elo as f64) / 400.0));
    let expected_loser = 1.0 - expected_winner;

    let new_winner = (winner_elo as f64 + k_winner * (1.0 - expected_winner)).round() as u32;
    let new_loser = (loser_elo as f64 + k_loser * (0.0 - expected_loser))
        .round()
        .max(100.0) as u32;

    (new_winner, new_loser)
}
