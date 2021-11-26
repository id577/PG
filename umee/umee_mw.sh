#!/bin/bash
WALLETS=(
"umee1fsh2n7429l2x022xdthf5w4l7jkaw8v43kqmq8"
"umee1dml765pf85lcu5y8nmm2fnjwjs4xvvqsq8vagp"
"umee1pfdd6cucne3lv9w8ks603mtukmd6t07a3zpmj2"
"umee1xcejpf5m94wshyu2cet48vg9ku343n2g80r607"
"umee1crht473nwg60v40upe6zj3n7tw24mgzy5y5flg"
"umee1579s65q7j8n3suhyt8mqsahzmqz5ngwpe6jn6a"
"umee13cktasn2dk29qwk2r7q9khv7p4p2exxmlyknwh"
"umee18hhsehuk23gtuuzfrsumm60ndy4r5gww3umkrs"
"umee124y982ymcfvtfxlek0c7n5sj35uhlsn0zuf5cj"
"umee1gtysc82zqa5n7022ygqzvzrtt7ychxk8mssxwu")
WALLETS_PASSWORD="splurgeola57"
RPC=("http://193.164.132.24:26657"
"http://178.170.49.138:26657/"
"http://213.246.45.198:26657/"
"http://172.105.168.226:26657/"
"http://3.34.147.65:26657/"
"http://95.111.231.65:26657/"
)
TARGET_WALLET="umee1wju82lrr8e5689rh5qum3n6ncjzrkyzfsnm088"
VAL_ADDRESS="umeevaloper1wju82lrr8e5689rh5qum3n6ncjzrkyzfshuqkd"
UUMEE_AMOUNT_TO_SEND=1 #uumee (not umee)
DELAY_TIME=10 #sec
GAS_AMOUNT=200000
FEES_AMOUNT=200
START_TX_COUNT=32
PID_ARRAY=()

SPD_TX=0
O_TIME=0
TEMP_TX_SPD=0

echo -e "# UMEE SPAMMER v0.0.0"
echo -e "# Choose mode:" 
echo -e " 1) Mode 1"
echo -e " 2) Mode 2"
echo -e " 3) Mode 3"
read -p "enter: " MODE

function main(){
sleep 5
CYCLE_M=0
while true; do
  CYCLE_M=$(( $CYCLE_M + 1 ))
	TRANSACTIONS=$(( 0 - $START_TX_COUNT ))
	WALLET_BALANCES=""
	VAR=1
	for item in ${WALLETS[*]} 
	do
		TRANSACTIONS=$(( $TRANSACTIONS + $(umeed query txs --events="message.sender=${item}" | grep -Eo "total_count: \"[0-9]*\"" | grep -Eo "[0-9]*") ))
		TEMP=$(umeed query bank balances ${item} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
		WALLET_BALANCES+="\nWALLET_${VAR} (${item}) = \e[32m${TEMP}\e[39m"
		VAR=$(( $VAR + 1 )) 
  done
clear
spd_tx $TRANSACTIONS $CYCLE_M
RESULT="TRANSACTIONS = \e[32m${TRANSACTIONS}\e[39m, WALLETS = \e[32m${#WALLETS[*]}\e[39m${WALLET_BALANCES}"
echo -e "${RESULT}"
echo -e ""
GT="PRESS ENTER TO STOP ALL SPAMMERS"
UT="."
for (( n=0; n<10; n++ )); do
  GT="$GT$UT"
  echo -en "\r${GT}"
  sleep 1
done
done
}

function spd_tx() {
if [ "$2" != "1" ]
then
  N_TIME=$SECONDS
  DIF_TIME=$(( $N_TIME - $O_TIME ))
  N_TX=$1
  DIF_TX=$(( $N_TX - $O_TX))
  C_TX_SPD=$(bc<<<"scale=2;$DIF_TX/$DIF_TIME")
  TEMP_TX_SPD=$(bc<<<"scale=2;$TEMP_TX_SPD+$C_TX_SPD")
  TEMP_CYCLE=$(( $2 - 1 ))
  A_TX_SPD=$(bc<<<"scale=2;$TEMP_TX_SPD/$TEMP_CYCLE")
  echo -e "CURRENT TX/s = \e[32m${C_TX_SPD}\e[39m, AVARAGE TX/s = \e[32m${A_TX_SPD}\e[39m"
else
  echo -e "CURRENT TX/s = \e[32mcalculating...\e[39m, AVARAGE TX/s = \e[32mcalculating...\e[39m"
fi
O_TIME=$SECONDS
O_TX=$1
}

function spammer_1(){
CYCLE=0
while true; do 
	CYCLE=$(( $CYCLE + 1 ))
	echo -e "" >> thread_${1}_logs.txt
	echo -e "" >> thread_${1}_logs.txt
	echo -e "" >> thread_${1}_logs.txt
	echo -e "Starting cycle № ${CYCLE}" >> thread_${1}_logs.txt
	VAR=1
	echo -e "Trying to send ${UUMEE_AMOUMT_TO_SEND}uumee from ${2} to ${TARGET_WALLET}..." >> thread_${1}_logs.txt
  CURRENT_BLOCK=$(curl -s http://localhost:26657/abci_info | jq -r .result.response.last_block_height)
	echo -e "${WALLETS_PASSWORD}\n" | umeed tx bank send ${2} ${TARGET_WALLET} ${UUMEE_AMOUNT_TO_SEND}uumee --chain-id "umeevengers-1c" --timeout-height $(( $CURRENT_BLOCK + 10 )) --from "${2}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --note "${VAL_ADDRESS}" -y >> thread_${1}_logs.txt
done
}

function spammer_2(){
CYCLE=0
while true; do 
	CYCLE=$(( $CYCLE + 1 ))
	echo -e "" >> thread_${1}_logs.txt
	echo -e "" >> thread_${1}_logs.txt
	echo -e "" >> thread_${1}_logs.txt
	echo -e "Starting cycle № ${CYCLE}" >> thread_${1}_logs.txt
  umeed tx bank send ${2} ${TARGET_WALLET} ${UUMEE_AMOUNT_TO_SEND}uumee --chain-id "umeevengers-1c" --from "${2}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --note "${VAL_ADDRESS}" --generate-only > u_tx_${1}.json
  echo -e "${WALLETS_PASSWORD}\n" | umeed tx sign u_tx_${1}.json --chain-id "umeevengers-1c" --from "${2}" --output-document=s_tx_${1}.json
  umeed tx broadcast s_tx_${1}.json >> thread_${1}_logs.txt
  sleep 10
done
}

function spammer_3(){
CYCLE=0
while true; do 
	CYCLE=$(( $CYCLE + 1 ))
	echo -e "" >> thread_${1}_logs.txt
	echo -e "" >> thread_${1}_logs.txt
	echo -e "" >> thread_${1}_logs.txt
	echo -e "Starting cycle № ${CYCLE}" >> thread_${1}_logs.txt
	VAR=1
  C_RPC_INDEX=$((RANDOM % ${#RPC[*]}))
  C_RPC=${RPC[$C_RPC_INDEX]}
	echo -e "Trying to send ${UUMEE_AMOUMT_TO_SEND}uumee from ${2} to ${TARGET_WALLET} via ${C_RPC}..." >> thread_${1}_logs.txt
  CURRENT_BLOCK=$(curl -s http://localhost:26657/abci_info | jq -r .result.response.last_block_height)
	echo -e "${WALLETS_PASSWORD}\n" | umeed tx bank send ${2} ${TARGET_WALLET} ${UUMEE_AMOUNT_TO_SEND}uumee --chain-id "umeevengers-1c" --timeout-height $(( $CURRENT_BLOCK + 10 )) --from "${2}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --node $C_RPC --note "${VAL_ADDRESS}" -y >> thread_${1}_logs.txt
done
}

function killAll() {
	for item in ${PID_ARRAY[*]}
	do
		kill -9 $item
		echo "${item} killed!"
	done
	echo "All spammers was killed! Exiting..."
	exit
}

if [ "$MODE" = "1" ]
then
  echo -e "MODE 1. Monitoring will be available in 10 seconds. Starting \e[32m${#WALLETS[*]}\e[39m spammer[s]..."
  sleep 3
  INDEX=0
  main &
  PID_ARRAY+=($!)
  for item in ${WALLETS[*]}
  do
      INDEX=$(( $INDEX + 1 ))
	    spammer_1 $INDEX $item &
	    PID_ARRAY+=($!)
	    echo "THREAD №${INDEX} with wallet address ${item} started with PID=${!}"
	    sleep 0.1
  done
  echo " ${PID_ARRAY[@]/%/$'\n'}" | sed 's/^ //' | column > PIDs.txt
  echo "All spammers was started! Working..."
  sleep 3
  clear
fi

if [ "$MODE" = "2" ]
then
  echo -e "MODE 2. Monitoring will be available in 10 seconds. Starting \e[32m${#WALLETS[*]}\e[39m spammer[s]..."
  sleep 3
  INDEX=0
  main &
  PID_ARRAY+=($!)
  for item in ${WALLETS[*]}
  do
      INDEX=$(( $INDEX + 1 ))
	    spammer_2 $INDEX $item &
	    PID_ARRAY+=($!)
	    echo "THREAD №${INDEX} with wallet address ${item} started with PID=${!}"
	    sleep 0.1
  done
  echo " ${PID_ARRAY[@]/%/$'\n'}" | sed 's/^ //' | column > PIDs.txt
  echo "All spammers was started! Working..."
  sleep 3
  clear
fi

if [ "$MODE" = "3" ]
then
  echo -e "MODE 3. Monitoring will be available in 10 seconds. Starting \e[32m${#WALLETS[*]}\e[39m spammer[s]..."
  sleep 3
  INDEX=0
  main &
  PID_ARRAY+=($!)
  for item in ${WALLETS[*]}
  do
      INDEX=$(( $INDEX + 1 ))
	    spammer_3 $INDEX $item &
	    PID_ARRAY+=($!)
	    echo "THREAD №${INDEX} with wallet address ${item} started with PID=${!}"
	    sleep 0.1
  done
  echo " ${PID_ARRAY[@]/%/$'\n'}" | sed 's/^ //' | column > PIDs.txt
  echo "All spammers was started! Working..."
  sleep 3
  clear
fi

while true; do
  read option
  case $option in
	  x) killAll;;
    "") killAll
  esac
done
