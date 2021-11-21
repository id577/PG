#!/bin/bash
WALLET_1_ADDRESS="umee1wju82lrr8e5689rh5qum3n6ncjzrkyzfsnm088"
WALLET_2_ADDRESS="umee1vlm35w9h2lcdwzwn3zxs7ct5w5ud8fx8gaqnl4"
DELAY=10

while true; do
WALLET_1_TX_COUNT=$(umeed query txs --events="message.sender=${WALLET_1_ADDRESS}" --output json |  jq -r '.txs[].tx.body.memo' | wc -l)
WALLET_2_TX_COUNT=$(umeed query txs --events="message.sender=${WALLET_2_ADDRESS}" --output json |  jq -r '.txs[].tx.body.memo' | wc -l)

let "TOTAL_TX_COUNT=WALLET_1_TX_COUNT+WALLET_2_TX_COUNT"

WALLET_1_BALANCE=$(umeed query bank balances ${WALLET_1_ADDRESS} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
WALLET_2_BALANCE=$(umeed query bank balances ${WALLET_2_ADDRESS} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")

RESULT="TRANSACTIONS=\e[32m${TOTAL_TX_COUNT}\e[39m, WALLET_1=\e[32m${WALLET_1_BALANCE}\e[39m, WALLET_2=\e[32m${WALLET_2_BALANCE}\e[39m"
DOT="."
clear
for (( VAR = 0; VAR < $DELAY; VAR++ )) do
  echo -e "${RESULT}"
  sleep 1
  RESULT+=${DOT}
  clear
done
done