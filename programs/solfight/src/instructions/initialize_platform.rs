use anchor_lang::prelude::*;

use crate::errors::SolFightError;
use crate::state::Platform;

#[derive(Accounts)]
pub struct InitializePlatform<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + Platform::INIT_SPACE,
        seeds = [Platform::SEED],
        bump,
    )]
    pub platform: Account<'info, Platform>,

    #[account(mut)]
    pub authority: Signer<'info>,

    /// CHECK: Treasury wallet that receives platform fees.
    pub treasury: UncheckedAccount<'info>,

    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializePlatform>, fee_bps: u16) -> Result<()> {
    require!(fee_bps <= 2500, SolFightError::InvalidFeeBps);

    let platform = &mut ctx.accounts.platform;
    platform.authority = ctx.accounts.authority.key();
    platform.fee_bps = fee_bps;
    platform.treasury = ctx.accounts.treasury.key();
    platform.total_games = 0;
    platform.total_volume = 0;
    platform.bump = ctx.bumps.platform;

    Ok(())
}
