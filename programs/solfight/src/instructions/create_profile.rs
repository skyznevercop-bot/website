use anchor_lang::prelude::*;

use crate::errors::SolFightError;
use crate::events::ProfileCreated;
use crate::state::PlayerProfile;

#[derive(Accounts)]
pub struct CreateProfile<'info> {
    #[account(
        init,
        payer = player,
        space = 8 + PlayerProfile::INIT_SPACE,
        seeds = [PlayerProfile::SEED, player.key().as_ref()],
        bump,
    )]
    pub profile: Account<'info, PlayerProfile>,

    #[account(mut)]
    pub player: Signer<'info>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<CreateProfile>, gamer_tag: String) -> Result<()> {
    require!(!gamer_tag.is_empty(), SolFightError::GamerTagEmpty);
    require!(gamer_tag.len() <= 16, SolFightError::GamerTagTooLong);

    let clock = Clock::get()?;
    let profile = &mut ctx.accounts.profile;

    profile.authority = ctx.accounts.player.key();
    profile.gamer_tag = gamer_tag.clone();
    profile.elo_rating = 1200;
    profile.wins = 0;
    profile.losses = 0;
    profile.total_pnl = 0;
    profile.current_streak = 0;
    profile.games_played = 0;
    profile.created_at = clock.unix_timestamp;
    profile.bump = ctx.bumps.profile;

    emit!(ProfileCreated {
        player: ctx.accounts.player.key(),
        gamer_tag,
        timestamp: clock.unix_timestamp,
    });

    Ok(())
}
