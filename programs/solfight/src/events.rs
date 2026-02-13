use anchor_lang::prelude::*;

#[event]
pub struct ProfileCreated {
    pub player: Pubkey,
    pub gamer_tag: String,
    pub timestamp: i64,
}

#[event]
pub struct GameCreated {
    pub game_id: u64,
    pub player_one: Pubkey,
    pub player_two: Pubkey,
    pub bet_amount: u64,
    pub timeframe_seconds: u32,
}

#[event]
pub struct PlayerDeposited {
    pub game_id: u64,
    pub player: Pubkey,
    pub amount: u64,
}

#[event]
pub struct GameStarted {
    pub game_id: u64,
    pub start_time: i64,
    pub end_time: i64,
}

#[event]
pub struct GameSettled {
    pub game_id: u64,
    pub winner: Pubkey,
    pub player_one_pnl: i64,
    pub player_two_pnl: i64,
    pub winner_new_elo: u32,
    pub loser_new_elo: u32,
}

#[event]
pub struct WinningsClaimed {
    pub game_id: u64,
    pub winner: Pubkey,
    pub payout: u64,
    pub fee: u64,
}
