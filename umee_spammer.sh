#!/bin/bash
WALLET_1_ADDRESS="umee1wju82lrr8e5689rh5qum3n6ncjzrkyzfsnm088"
WALLET_2_ADDRESS="umee1vlm35w9h2lcdwzwn3zxs7ct5w5ud8fx8gaqnl4"
WALLET_1_PASSWORD=""
WALLET_2_PASSWORD=""
VAL_ADDRESS="umeevaloper1wju82lrr8e5689rh5qum3n6ncjzrkyzfshuqkd"
UUMEE_AMOUMT_TO_SEND=1000 #uumee (not umee)
DELAY_TIME=1 #sec
GAS_AMOUNT=200000
FEES_AMOUNT=200

while true; do
  echo -e "${WALLET_1_PASSWORD}\n" | umeed tx bank send ${WALLET_1_ADDRESS} ${WALLET_2_ADDRESS} ${UUMEE_AMOUMT_TO_SEND}uumee --chain-id "umeevengers-1c" --from "${WALLET_1_ADDRESS}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --note "${VAL_ADDRESS}" -y
  sleep ${DELAY_TIME}
  echo "sleep ${DELAY_TIME} sec"
  echo -e "${WALLET_2_PASSWORD}\n" | umeed tx bank send ${WALLET_2_ADDRESS} ${WALLET_1_ADDRESS} ${UUMEE_AMOUMT_TO_SEND}uumee --chain-id "umeevengers-1c" --from "${WALLET_2_ADDRESS}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --note "${VAL_ADDRESS}" -y
  sleep ${DELAY_TIME}
  echo "sleep ${DELAY_TIME} sec"
  WALLET_1_BALANCE=$(umeed query bank balances ${WALLET_1_ADDRESS} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
  sleep ${DELAY_TIME}
  WALLET_2_BALANCE=$(umeed query bank balances ${WALLET_2_ADDRESS} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
  sleep ${DELAY_TIME}
  echo "WALLET_1_BALANCE=${WALLET_1_BALANCE}, WALLET_2_BALANCE=${WALLET_2_BALANCE}"
done