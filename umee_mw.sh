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
"umee1gtysc82zqa5n7022ygqzvzrtt7ychxk8mssxwu"
"umee1l390hcav6asqt8t3rule8fx9p9fpk5d76yep7a"
"umee1gdy33vkjnuk2cm4n9tv3cmvsd80dk0t33pqkr4"
"umee1esqp59gxyd3utysyz3tje8vexftqt4f9px5k58")
WALLETS_PASSWORD=""
TARGET_WALLET="umee1wju82lrr8e5689rh5qum3n6ncjzrkyzfsnm088"
VAL_ADDRESS="umeevaloper1wju82lrr8e5689rh5qum3n6ncjzrkyzfshuqkd"
UUMEE_AMOUMT_TO_SEND=1 #uumee (not umee)
DELAY_TIME=10 #sec
GAS_AMOUNT=200000
FEES_AMOUNT=200
START_TX_COUNT=32
PID_ARRAY=()
echo -e "Monitoring will be available in 10 seconds. Starting \e[32m${#WALLETS[*]}\e[39m spammer[s]..."
sleep 5
clear
function main(){
sleep 10
while true; do
	TRANSACTIONS=$(( 0 - $START_TX_COUNT ))
	WALLET_BALANCES=""
	VAR=1
	for item in ${WALLETS[*]} 
	do
		TRANSACTIONS=$(( $TRANSACTIONS + $(umeed query txs --events="message.sender=${item}" | grep -Eo "total_count: \"[0-9]*\"" | grep -Eo "[0-9]*") ))
		TEMP=$(umeed query bank balances ${item} | grep -oE "amount: \"[0-9]*" | grep -oE "[0-9]*")
		WALLET_BALANCES+="\nWALLET_${VAR}=\e[32m${TEMP}\e[39m"
		VAR=$(( $VAR + 1 )) 
  done
RESULT="You can stop spammers by pressing Enter.\nTHREADS=\e[32m${THREADS}\e[39m, TRANSACTIONS=\e[32m${TRANSACTIONS}\e[39m, WALLETS=\e[32m${#WALLETS[*]}\e[39m${WALLET_BALANCES}"
clear
echo -e "${RESULT}"
sleep 10
done
}

function spammer(){
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
	echo -e "${WALLETS_PASSWORD}\n" | umeed tx bank send ${2} ${TARGET_WALLET} ${UUMEE_AMOUMT_TO_SEND}uumee --chain-id "umeevengers-1c" --timeout-height $(( $CURRENT_BLOCK + 5 )) --from "${2}" --gas ${GAS_AMOUNT} --fees ${FEES_AMOUNT}uumee --note "${VAL_ADDRESS}" -y >> thread_${1}_logs.txt
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
for item in ${WALLETS[*]}
do
    INDEX=$(( $INDEX + 1 ))
	spammer $INDEX $item &
	PID_ARRAY+=($!)
	echo "THREAD №${INDEX} with wallet address ${item} started with PID=${!}"
	sleep 0.1
done
echo " ${PID_ARRAY[@]/%/$'\n'}" | sed 's/^ //' | column > PIDs.txt
echo "All spammers was started! Working..."
read option
case $option in
	x) killAll;;
  "") killAll
esac
