use anchor_lang::prelude::*;

#[error_code]
pub enum SolFightError {
    #[msg("Bet amount must be greater than zero.")]
    InvalidBetAmount,
    #[msg("Game is not in Active status.")]
    GameNotActive,
    #[msg("Game is not in Pending status.")]
    GameNotPending,
    #[msg("Signer is not a player in this game.")]
    NotAPlayer,
    #[msg("Game has already been settled.")]
    AlreadySettled,
    #[msg("Both players must deposit before the match can start.")]
    EscrowNotFull,
    #[msg("Only the platform authority can perform this action.")]
    Unauthorized,
    #[msg("Only the winner can claim winnings.")]
    NotWinner,
    #[msg("Player has already deposited for this game.")]
    AlreadyDeposited,
    #[msg("Gamer tag exceeds maximum length of 16 characters.")]
    GamerTagTooLong,
    #[msg("Gamer tag cannot be empty.")]
    GamerTagEmpty,
    #[msg("Fee basis points must be between 0 and 2500 (25%).")]
    InvalidFeeBps,
    #[msg("Arithmetic overflow.")]
    MathOverflow,
    #[msg("Game must be Tied or Cancelled for refund.")]
    NotRefundable,
    #[msg("Game must be Settled or Forfeited for claim.")]
    NotClaimable,
    #[msg("Escrow token account must be empty before closing the game.")]
    EscrowNotEmpty,
    #[msg("Game must be fully settled before it can be closed.")]
    GameNotSettled,
}
