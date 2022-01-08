#!/bin/bash
UMEE_WALLET=""
UMEE_WALLET_PASSWORD=""
ETH_WALLET=""
ETH_PK=""
ETH_RPC="http://localhost:8545"
CONTRACT_ADDRESS="0xe54fbaecc50731afe54924c40dfd1274f718fe02"
FEES=200
FEES_BRIDGE=1
API="1ZD4C1DWAI7AVZ73DNCGUUGFIV3RDPSKCG"
ETH_PRICE=500
UMEE_PRICE=1.4

ORC_START_BALANCE=$(curl -s -X POST -d "module=account&action=balance&address=${ORC_WALLET}&tag=latest&apikey=${API}" https://api-goerli.etherscan.io/api | grep -Eo "result\":\"[0-9]+" | grep -Eo [0-9]+)
ORC_START_BALANCE=$(bc<<<"scale=6;$ORC_START_BALANCE/1000000000000000000")
ORC_UMEE_START_BALANCE=$(curl -s -X POST -d "module=account&action=tokenbalance&contractaddress=${CONTRACT_ADDRESS}&address=${ORC_WALLET}&tag=latest&apikey=${API}" https://api-goerli.etherscan.io/api | grep -Eo "result\":\"[0-9]+" | grep -Eo [0-9]+)
ORC_UMEE_START_BALANCE=$(bc<<<"scale=6;$ORC_UMEE_START_BALANCE/1000000")

#ORC_START_BALANCE=1.429987
#ORC_UMEE_START_BALANCE=33.869722

echo -e "# UMEE GW v0.0.0"
echo -e "# Choose mode:" 
echo -e " 0) MODE 0 (Only Monitoring)"
echo -e " 1) MODE 1 (send ONLY to ETH network)"
echo -e " 2) MODE 2 (send ONLY to COSMOS network)"
echo -e " 3) MODE 3 (send to ETH and COSMOS networks)"
read -p "Choose MODE: " MODE

TX_TO_ETH=0
TX_TO_COSMOS=0
TIMESTAMP=$(date +%s)

if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
	read -p "How many transactions need to be sent to ETH network: " TX_TO_ETH
	read -p "How many uumee to send to ETH (1 by default): " UUMEE_AMOUNT_TO_SEND_TO_ETH
	UUMEE_AMOUNT_TO_SEND_TO_ETH=${UUMEE_AMOUNT_TO_SEND_TO_ETH:-1}
fi
if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
	read -p "How many transactions need to be sent to COSMOS network: " TX_TO_COSMOS
	read -p "How many uumee to send to COSMOS (1 by default): " UUMEE_AMOUNT_TO_SEND_TO_COSMOS
	UUMEE_AMOUNT_TO_SEND_TO_COSMOS=${UUMEE_AMOUNT_TO_SEND_TO_COSMOS:-1}
fi
read -p "Enter delay time (delay between TXs, sec, 60 by dafault): " DELAY_TIME
DELAY_TIME=${DELAY_TIME:-60}
if [ "$MODE" = "3" ]; then
	read -p "Enter cycle shift for ETH > COSMOS TXs (how many cycles will be skipped before the script starts sending transactions from ETH to COSMOS, 0 by default) " CYCLE_SHIFT
fi
CYCLE_SHIFT=${CYCLE_SHIFT:-0}
sleep 1

function monitoring(){
	clear
	UMEE_BALANCE=$(umeed q bank balances $UMEE_WALLET | grep -Eo "amount: \"[0-9]+" | grep -Eo [0-9]+)
	ETH_BALANCE=$(curl -s -X POST -d "module=account&action=balance&address=${ETH_WALLET}&tag=latest&apikey=${API}" https://api-goerli.etherscan.io/api | grep -Eo "result\":\"[0-9]+" | grep -Eo [0-9]+)
	ETH_BALANCE=$(bc<<<"scale=6;$ETH_BALANCE/1000000000000000000")
	UMEE_AT_ETH_BALANCE=$(curl -s -X POST -d "module=account&action=tokenbalance&contractaddress=${CONTRACT_ADDRESS}&address=${ETH_WALLET}&tag=latest&apikey=${API}" https://api-goerli.etherscan.io/api | grep -Eo "result\":\"[0-9]+" | grep -Eo [0-9]+)
  
  ORC_BALANCE=$(curl -s -X POST -d "module=account&action=balance&address=${ORC_WALLET}&tag=latest&apikey=${API}" https://api-goerli.etherscan.io/api | grep -Eo "result\":\"[0-9]+" | grep -Eo [0-9]+)
  ORC_BALANCE=$(bc<<<"scale=6;$ORC_BALANCE/1000000000000000000")
  ORC_UMEE_BALANCE=$(curl -s -X POST -d "module=account&action=tokenbalance&contractaddress=${CONTRACT_ADDRESS}&address=${ORC_WALLET}&tag=latest&apikey=${API}" https://api-goerli.etherscan.io/api | grep -Eo "result\":\"[0-9]+" | grep -Eo [0-9]+)
  ORC_UMEE_BALANCE=$(bc<<<"scale=6;$ORC_UMEE_BALANCE/1000000")
  
  LOSS=$(bc<<<"scale=6;$ORC_START_BALANCE-$ORC_BALANCE")
  PROFIT=$(bc<<<"scale=2;$ORC_UMEE_BALANCE-$ORC_UMEE_START_BALANCE")
 
  
  LOSS_USD=$(bc<<<"scale=2;$LOSS*$ETH_PRICE")
  PROFIT_USD=$(bc<<<"scale=2;$PROFIT*$UMEE_PRICE")
  PNL=$(bc<<<"scale=2;$PROFIT-$LOSS")
  
	TX_PEGGO=$(curl -s localhost:1317/peggy/v1/module_state | grep ${UMEE_WALLET} | wc -l)
	echo -e "------------ UMEE-GW MONITOR ------------"
	echo -e "SETTINGS: MODE: ${MODE}; DT: ${DELAY_TIME}; CS: ${CYCLE_SHIFT}"
	echo -e ""
  echo -e "WALLETS STATS:"
	echo -e "umee wallet: \e[32m${UMEE_BALANCE}\e[39m uumee"
	echo -e "ethereum wallet: \e[32m${ETH_BALANCE}\e[39m eth \e[32m${UMEE_AT_ETH_BALANCE}\e[39m uumee"
  echo -e ""
  echo -e "ORCHESTRATOR STATS:"
  echo -e "balance: \e[32m${ORC_BALANCE}\e[39m eth \e[32m${ORC_UMEE_BALANCE}\e[39m umee"
  echo -e "profit: \e[32m${PROFIT}\e[39m umee (\e[32m${PROFIT_USD}\e[39m USD)"
  echo -e "loss: \e[31m${LOSS}\e[39m eth (\e[31m${LOSS_USD}\e[39m USD)"
  if [[ $(bc -l <<< "${PNL}>0") -eq 1 ]]; then
    echo -e "PnL: \e[32m${PNL}\e[39m USD"
  else
    echo -e "PnL: \e[31m${PNL}\e[39m USD"
  fi
	if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
    echo -e ""
		echo -e "SUCCESSFUL TX_TO_ETH: ${SS_TX_TO_ETH}/${TX_TO_ETH}"
		echo -e "ERRORS: \e[31m${ERR_TX_TO_ETH}\e[39m"
	fi
	if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
   echo -e ""
    if [ $CYCLE_SHIFT -gt 0 ] && [ "$MODE" = "3" ]; then
      echo -e "TX to COSMOS network will start in \e[32m${CYCLE_SHIFT}\e[39m cycles..."
    fi
		echo -e "SUCCESSFUL TX_TO_COSMOS = ${SS_TX_TO_COSMOS}/${TX_TO_COSMOS}"
		echo -e "ERRORS: \e[31m${ERR_TX_TO_COSMOS}\e[39m"
	fi
	echo -e ""
  echo -e "TXs in PEGGO: ${TX_PEGGO}"
	echo -e "-----------------------------------------"
  echo -e ""
	echo -e "Next update in ${DELAY_TIME} sec. Press ctrl+c to abort..."
}

function send_to_eth(){
	UUMEE_AMOUNT_TO_SEND_TO_ETH=$(($UUMEE_AMOUNT_TO_SEND_TO_ETH+1))
	echo -e "" >> ${TIMESTAMP}_TXs_TO_ETH_LOG.txt
	echo -e "${UMEE_WALLET_PASSWORD}\n" | umeed tx peggy send-to-eth $ETH_WALLET ${UUMEE_AMOUNT_TO_SEND_TO_ETH}uumee ${FEES_BRIDGE}uumee --from ${UMEE_WALLET} --chain-id=umee-alpha-mainnet-2 --keyring-backend=os --fees=${FEES}uumee --broadcast-mode block -y &>> ${TIMESTAMP}_TXs_TO_ETH_LOG.txt
	if [ "$?" = "0" ]; then
		SS_TX_TO_ETH=$(($SS_TX_TO_ETH+1))
	else
		ERR_TX_TO_ETH=$(($ERR_TX_TO_ETH+1))
	fi
	
}

function send_to_cosmos(){
	UMEE_AT_ETH_BALANCE=$(curl -s -X POST -d "module=account&action=tokenbalance&contractaddress=${CONTRACT_ADDRESS}&address=${ETH_WALLET}&tag=latest&apikey=${API}" https://api-goerli.etherscan.io/api | grep -Eo "result\":\"[0-9]+" | grep -Eo [0-9]+)
	if [ $UMEE_AT_ETH_BALANCE -ge $UUMEE_AMOUNT_TO_SEND_TO_COSMOS ]; then
		UUMEE_AMOUNT_TO_SEND_TO_COSMOS=$(($UUMEE_AMOUNT_TO_SEND_TO_COSMOS+1))
		echo -e "" >> ${TIMESTAMP}_TXs_TO_COSMOS_LOG.txt
		peggo bridge send-to-cosmos $CONTRACT_ADDRESS $UMEE_WALLET $UUMEE_AMOUNT_TO_SEND_TO_COSMOS --eth-pk $ETH_PK --eth-rpc "${ETH_RPC}" &>> ${TIMESTAMP}_TXs_TO_COSMOS_LOG.txt
		if [ "$?" = "0" ]; then
			SS_TX_TO_COSMOS=$(($SS_TX_TO_COSMOS+1))
		else
			ERR_TX_TO_COSMOS=$(($ERR_TX_TO_COSMOS+1))
		fi
	else
		echo "" >> ${TIMESTAMP}_TXs_TO_ETH_LOG.txt
		echo "ERROR! Uumee balance in ETH network is less than it is needed to be send. Transaction canceled!" >> ${TIMESTAMP}_TXs_TO_ETH_LOG.txt
		ERR_TX_TO_ETH=$(($ERR_TX_TO_ETH+1))
	fi
}

function exitd() {
	if [ "$SS_TX_TO_COSMOS" = "$TX_TO_COSMOS" ] && [ "$SS_TX_TO_ETH" = "$TX_TO_ETH" ] ; then
		if [ "$TX_TO_ETH" != "0" ]; then
			if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
				cat ${TIMESTAMP}_TXs_TO_ETH_LOG.txt | jq .txhash | sed 's/"//g' >> ${TIMESTAMP}_TX_TO_ETH_HASHs.txt

				#curl -s -X POST -d "module=account&action=tokentx&address=${ETH_WALLET}&startblock=0&endblock=999999999&sort=asc&apikey=${API}" https://api-goerli.etherscan.io/api | jq -r ".result[] | select(.to==\"$ETH_WALLET\") | .hash" >> ${TIMESTAMP}_TX_TO_ETH_HASHs.txt
				
				echo -e "COSMOS -> ETH:" >> ${TIMESTAMP}_FULL_RESULT.txt
				IFS=' ' read -r -a HEIGHT_ARRAY <<< $(echo -e $(cat ${TIMESTAMP}_TXs_TO_ETH_LOG.txt | jq '.height'| sed 's/"//g') | sed 's/\n/ /g')
				IFS=' ' read -r -a HASH_ARRAY <<< $(echo -e $(cat ${TIMESTAMP}_TXs_TO_ETH_LOG.txt | jq '.txhash'| sed 's/"//g') | sed 's/\n/ /g')
				IFS=' ' read -r -a AMOUNT_ARRAY <<< $(echo -e $(cat ${TIMESTAMP}_TXs_TO_ETH_LOG.txt | jq '.logs[].events[] | select(.type=="transfer")' | jq '.attributes[] | select(.key=="amount")' | jq .value | sed 's/"//g') | sed 's/\n/ /g')
				for (( n=0; n<$SS_TX_TO_ETH; n++ )); do
					echo -e "${HEIGHT_ARRAY[n]} ${HASH_ARRAY[n]} ${AMOUNT_ARRAY[n]}" >> ${TIMESTAMP}_FULL_RESULT.txt
				done 
			fi
		fi
		if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
			if [ "$TX_TO_COSMOS" != "0" ]; then
				cat ${TIMESTAMP}_TXs_TO_COSMOS_LOG.txt | grep -Eo "Transaction: [A-Za-z0-9]+" | awk '{print $2}' >> ${TIMESTAMP}_TX_TO_COSMOS_HASHs.txt
	
				echo -e "ETH -> COSMOS:" >> ${TIMESTAMP}_FULL_RESULT.txt
				IFS=' ' read -r -a AMOUNT_ARRAY <<< $(echo -e $(cat ${TIMESTAMP}_TXs_TO_COSMOS_LOG.txt | grep -Eo "Amount: [0-9]+" | awk '{print $2}') | sed 's/\n/ /g')
				IFS=' ' read -r -a HASH_ARRAY <<< $(echo -e $(cat ${TIMESTAMP}_TXs_TO_COSMOS_LOG.txt | grep -Eo "Transaction: [A-Za-z0-9]+" | awk '{print $2}') | sed 's/\n/ /g')
				for (( n=0; n<$SS_TX_TO_COSMOS; n++ )); do
					echo -e "${HASH_ARRAY[n]} ${AMOUNT_ARRAY[n]}" >> ${TIMESTAMP}_FULL_RESULT.txt
				done 
			fi
		fi
		echo ""
		echo "Done!"
		exit
	fi
}

SS_TX_TO_ETH=0
SS_TX_TO_COSMOS=0
ERR_TX_TO_ETH=0
ERR_TX_TO_COSMOS=0

if [ "$MODE" = "0" ]; then
  while true; do
  monitoring
  sleep $DELAY_TIME
  done
fi


monitoring
while true; do
if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
	if [ $SS_TX_TO_ETH -lt $TX_TO_ETH ]; then
		send_to_eth
		monitoring
		sleep $DELAY_TIME
	fi
	exitd
fi
if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
	if [ $SS_TX_TO_COSMOS -lt $TX_TO_COSMOS ]; then
		if [ $CYCLE_SHIFT -gt 0 ] && [ "$MODE" = "3" ]; then
			CYCLE_SHIFT=$(($CYCLE_SHIFT-1))
		else
			send_to_cosmos
			monitoring
			sleep $DELAY_TIME
		fi
	fi
	exitd
fi
done