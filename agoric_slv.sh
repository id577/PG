#!/bin/bash

WALLETS=(
"agoric1ugyyzsapngey28gpv4uxj9wawkqe9ft3q28fms"
"agoric1ugyyzsapngey28gpv4uxj9wawkqe9ft3q28fms"
)
WALLETS_PASSWORD=
TARGET_WALLET=agoric1ugyyzsapngey28gpv4uxj9wawkqe9ft3q28fms

DELAY_TIME=21600
RPC=https://agoric-rpc.polkachu.com:443
AGORIC_CHAIN="agoric-3"
FEES=0
MSG=1

function senditshit(){
	for item in ${WALLETS[*]}; do
		echo -e ""
		echo -e "Working with ${item}"
		echo -e "Trying to claim rewards..."
		while [ $MSG -ne 0 ]; do
			echo -e "${WALLETS_PASSWORD}\n" | ag0 tx distribution withdraw-all-rewards --from=${item} --chain-id=${AGORIC_CHAIN} --fees=${FEES}ubld --node ${RPC} -y &>> agoric_slv.logs
			MSG=$?
			if [ $MSG -eq 0 ]; then
				echo -e "Successfully withdraw-all-rewards for ${item}!"
			else
				echo -e "Failed to withdraw-all-rewards for ${item}. Retry in 10 sec..."
			fi
		sleep 10
		done
		MSG=1
		
		echo -e "Checking available balance for ${item}..."
		RESULT=$(echo -e "${WALLETS_PASSWORD}\n" | ag0 tx bank send $item $TARGET_WALLET 10000000000ubld --chain-id=${AGORIC_CHAIN} --fees ${FEES}ubld --node ${RPC} -b block -y) 
		RESULT=$(echo $RESULT | grep -Eo "[0-9]+ubld is smaller" | grep -Eo "[0-9]+")
    echo -e "Total ${RESULT}ubld available for send. Trying to send ubld to ${TARGET_WALLET}"
    sleep 10
		MSG=1
		
		while [ $MSG -ne 0 ]; do
			echo -e "${WALLETS_PASSWORD}\n" | ag0 tx bank send $item $TARGET_WALLET ${RESULT}ubld --chain-id=${AGORIC_CHAIN} --fees ${FEES}ubld --node ${RPC} -y &>> agoric_slv.logs
			MSG=$?
			if [ $MSG -eq 0 ]; then
				echo -e "Successfully sended ${RESULT}ubld to ${TARGET_WALLET}!"
			else
				echo -e "Failed to send ${RESULT}ubld to ${TARGET_WALLET}. Retry in 10 sec..."
				RESULT=10000000
			fi	
		sleep 10
		done
		MSG=1
done
}

while true; do
  senditshit
  echo -e "Sleep ${DELAY_TIME} sec."
  sleep $DELAY_TIME
done