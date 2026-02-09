#!/bin/bash
source .env

read -p "Enter keystore account name: " KEYSTORE_NAME

forge script script/AuctionMainnetDeployer.s.sol:AuctionMainnetDeployerScript \
    --rpc-url "$MAINNET_RPC_URL" \
    --account "$KEYSTORE_NAME" \
    --broadcast \
    --verify \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    -vvvv
