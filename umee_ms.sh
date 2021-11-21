#!/bin/bash
WALLETS=("umee1wju82lrr8e5689rh5qum3n6ncjzrkyzfsnm088" "umee1vlm35w9h2lcdwzwn3zxs7ct5w5ud8fx8gaqnl4")
WALLETS_PASSWORD="splurgeola57"
VAL_ADDRESS="umeevaloper1wju82lrr8e5689rh5qum3n6ncjzrkyzfshuqkd"
UUMEE_AMOUMT_TO_SEND=1 #uumee (not umee)
DELAY_TIME=10 #sec
GAS_AMOUNT=200000
FEES_AMOUNT=200
START_TX_COUNT=32
PID_ARRAY=()
read -p "Enter number of threads: " THREADS
echo "Starting $THREADS spammer[s]..."
sleep 5
clear
function main(){
while true; do
	TRANSACTIONS=$(( 0 - $START_TX_COUNT ))
	WALLET_BALANCES=""
	VAR=1
	for item in ${WALLETS[*]} 
	do
		TRANSACTIONS=$(( $TRANSACTIONS + $(umeed query txs --events="message.sender=${item}" | grep -Eo "total_count: \"[0-9]*\"" | grep -Eo "[0-9]*") ))
		TEMP=$(umeed query bank balances ${item} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
		WALLET_BALANCES+=", WALLET_${VAR}=\e[32m${TEMP}\e[39m"
		VAR=$(( $VAR + 1 )) 
  done
RESULT="THREADS=\e[32m${THREADS}\e[39m, TRANSACTIONS=\e[32m${TRANSACTIONS}\e[39m${WALLET_BALANCES}"
DOT="."
for (( VAR = 0; VAR < $DELAY_TIME; VAR++ )) do
  echo -e "${RESULT}"
  sleep 1
  RESULT+=${DOT}
  clear
done
done
}

function spammer(){
CYCLE=0
while true; do 
	CYCLE=$(( $CYCLE + 1 ))
  echo -e "" >> thread_${1}_logs
  echo -e "" >> thread_${1}_logs
  echo -e "" >> thread_${1}_logs
	echo -e "Starting cycle № ${CYCLE}" >> thread_${1}_logs.txt
	MAX_BALANCE=0
	MIN_BALANCE=2147483647
	VAR=1
	for item in ${WALLETS[*]}
	do
		TEMP=$(umeed query bank balances ${item} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
		WALLET_BALANCES+=", WALLET_${VAR}=${TEMP}"
		VAR=$(( $VAR + 1 ))
		if [ "$TEMP" -ge "$MAX_BALANCE" ]
		then
			MAX_BALANCE=$TEMP
			MAX_BALANCE_WALLET=$item
		fi      
		if [ "$TEMP" -le "$MIN_BALANCE" ]
		then
			MIN_BALANCE=$TEMP
			MIN_BALANCE_WALLET=$item      
		fi
	done
	echo -e "Trying to send ${UUMEE_AMOUMT_TO_SEND}uumee from ${MAX_BALANCE_WALLET} to ${MIN_BALANCE_WALLET} ..." >> thread_${1}_logs.txt
	echo -e "${WALLETS_PASSWORD}\n" | umeed tx bank send ${MAX_BALANCE_WALLET} ${MIN_BALANCE_WALLET} ${UUMEE_AMOUMT_TO_SEND}uumee --chain-id "umeevengers-1c" --from "${MAX_BALANCE_WALLET}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --note "${VAL_ADDRESS}" -y >> thread_${1}_logs.txt
done
}

function killAll() {
	for item in ${PID_ARRAY[*]}
	do
		kill -9 $item
		echo "${item} killed"
	done
	echo "All spammers was killed! Exiting..."
	exit
}

INDEX=0
main &
PID_ARRAY+=($!)
for (( VAR = 0; VAR < $THREADS; VAR++ )) 
do
  INDEX=$(( $INDEX + 1 ))
	spammer $INDEX &
	PID_ARRAY+=($!)
done
echo " ${PID_ARRAY[@]/%/$'\n'}" | sed 's/^ //' | column > PIDs.txt
read option
case $option in
	x) killAll;;
  "") killAll
esac
