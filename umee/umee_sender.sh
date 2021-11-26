#!/bin/bash
VAL_ADDRESS=""
SOURCE_WALLET=""
SOURCE_WALLET_PASSWORD=""
TARGET_WALLETS=()
UUMEE_AMOUMT_TO_SEND=100000 #uumee (not umee)
GAS_AMOUNT=200000
FEES_AMOUNT=200
echo "Starting in 5 sec..."
sleep 5


for item in ${TARGET_WALLETS[*]}; do
	echo -e ""
	echo -e "Trying to send ${UUMEE_AMOUMT_TO_SEND}uumee from ${SOURCE_WALLET} to ${item}..."
	echo -e "${SOURCE_WALLET_PASSWORD}\n" | umeed tx bank send ${SOURCE_WALLET} ${item} ${UUMEE_AMOUMT_TO_SEND}uumee --chain-id "umeevengers-1c" --from "${2}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --note "${VAL_ADDRESS}" -y
	sleep 1
done
echo -e ""
echo "done!"
}

