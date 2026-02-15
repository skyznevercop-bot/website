#!/bin/bash
# SolFight Program Deployment Script
# Run this after funding the deployer wallet with ~4 SOL.

set -e

SOLANA_BIN="/Users/antoninalarcon/.local/share/solana/install/releases/stable-42c10bf3385efbb369c8fd6da9bb59e0562bce50/solana-release/bin"
export PATH="$SOLANA_BIN:/Users/antoninalarcon/.cargo/bin:$PATH"

PROJECT_DIR="/Users/antoninalarcon/Desktop/Coding/Trading_website/trading_website"
PROGRAM_SO="$PROJECT_DIR/programs/solfight/target/deploy/solfight.so"
PROGRAM_KEYPAIR="$PROJECT_DIR/target/deploy/solfight-keypair.json"
DEPLOYER_KEYPAIR="$HOME/.config/solana/id.json"

echo "=== SolFight Deployment ==="
echo ""
echo "Program ID: 268xoH5VPMgtcuaBgXimyRHebsubszqQzPUrU5duJLL8"
echo "Deployer:   $(solana address -k $DEPLOYER_KEYPAIR)"
echo "Treasury:   5NXJKzgx9FbR9jx6XXHLP9zdJdY8gfaLfr6wzo9eZdzJ"
echo ""

# Check balance
BALANCE=$(solana balance --url mainnet-beta | awk '{print $1}')
echo "Deployer balance: $BALANCE SOL"

if (( $(echo "$BALANCE < 3" | bc -l) )); then
    echo "ERROR: Need at least 3 SOL. Current balance: $BALANCE SOL"
    echo "Send SOL to: $(solana address -k $DEPLOYER_KEYPAIR)"
    exit 1
fi

echo ""
echo "Deploying program to mainnet..."
solana program deploy \
    "$PROGRAM_SO" \
    --program-id "$PROGRAM_KEYPAIR" \
    --keypair "$DEPLOYER_KEYPAIR" \
    --url mainnet-beta \
    --with-compute-unit-price 50000

echo ""
echo "Program deployed successfully!"
echo "Program ID: 268xoH5VPMgtcuaBgXimyRHebsubszqQzPUrU5duJLL8"
echo ""
echo "Next step: Run scripts/initialize_platform.ts to initialize the platform PDA."
