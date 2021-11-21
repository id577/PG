#!/bin/bash

WALLETS=("umee1wju82lrr8e5689rh5qum3n6ncjzrkyzfsnm088" "umee1vlm35w9h2lcdwzwn3zxs7ct5w5ud8fx8gaqnl4")
START_TX_COUNT=32
DELAY=10

while true; do
TRANSACTIONS=$(( 0 - $START_TX_COUNT ))
WALLET_BALANCES=""
VAR=1
for item in ${WALLETS[*]} 
do
  TRANSACTIONS=$(( $TRANSACTIONS + $(umeed query txs --events="message.sender=${item}" --output json |  jq -r '.txs[].tx.body.memo' | wc -l) ))
  TEMP=$(umeed query bank balances ${item} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
  WALLET_BALANCES+=", WALLET_${VAR}=\e[32m${TEMP}\e[39m"
  VAR=$(( $VAR + 1 )) 
done

RESULT="TRANSACTIONS=\e[32m${TRANSACTIONS}\e[39m${WALLET_BALANCES}"
DOT="."
clear
for (( VAR = 0; VAR < $DELAY; VAR++ )) do
  echo -e "${RESULT}"
  sleep 1
  RESULT+=${DOT}
  clear
done
done