#!/bin/bash
UMEE_WALLET=""
UMEE_WALLET_PASSWORD=""
ETH_WALLET=""
ETH_PK=""
ETH_RPC=""
CONTRACT_ADDRESS="0xF20f98d098531Ba0Fdd6652C97f3da448C4E3962"
FEES=200
FEES_BRIDGE=1
DELAY_TIME=60 #sec, delay between transactions
CYCLE_SHIFT=10 #how many cycles will be skipped before the script starts sending transactions from ETH to COSMOS
UUMEE_AMOUNT_TO_SEND=1 #uumee (not umee)


echo -e "# UMEE GW v0.0.0"
echo -e "# Choose mode:" 
echo -e " 1) MODE 1 (send ONLY to ETH network)"
echo -e " 2) MODE 2 (send ONLY to COSMOS network)"
echo -e " 3) MODE 3 (send to ETH and COSMOS networks)"
read -p "Choose MODE: " MODE
TX_TO_ETH=0
TX_TO_COSMOS=0
if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
	read -p "How many transactions need to be sent to ETH network: " TX_TO_ETH
	TX_COUNT_MESSAGE="TXs to ETH network: ${TX_TO_ETH};"
fi
if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
	read -p "How many transactions need to be sent to COSMOS network: " TX_TO_COSMOS
	TX_COUNT_MESSAGE="${TX_COUNT_MESSAGE}TXs to COSMOS network: ${TX_TO_COSMOS};"
fi
echo -e "You choose MODE ${MODE}"
echo -e $TX_COUNT_MESSAGE
sleep 3

function monitoring(){
	clear
	UMEE_BALANCE=$(umeed q bank balances $UMEE_WALLET | grep -Eo "amount: \"[0-9]+" | grep -Eo [0-9]+)
	echo -e "------------ UMEE-GW MONITOR ------------"
  echo -e ""
	echo -e "UMEE_WALLET: \e[32m${UMEE_BALANCE}\e[39m uumee"
	echo -e "ETH_WALLET: \e[32mn/a\e[39m eth; \e[32mn/a\e[39m uumee"
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
	echo -e "----------------------------------------"
  echo -e ""
  echo -e "press ctrl+c to abort..."
}

function send_to_eth(){
  echo -e "" >> TXs_TO_ETH_LOG.txt
	echo -e "${UMEE_WALLET_PASSWORD}\n" | umeed tx peggy send-to-eth $ETH_WALLET ${UUMEE_AMOUNT_TO_SEND}uumee ${FEES_BRIDGE}uumee --from ${UMEE_WALLET} --chain-id=umee-alpha-mainnet-2 --keyring-backend=os --fees=${FEES}uumee -y &>> TXs_TO_ETH_LOG.txt
	if [ "$?" = "0" ]; then
		SS_TX_TO_ETH=$(($SS_TX_TO_ETH+1))
	else
		ERR_TX_TO_ETH=$(($ERR_TX_TO_ETH+1))
	fi
}

function send_to_cosmos(){
  echo -e "" >> TXs_TO_COSMOS_LOG.txt
	peggo bridge send-to-cosmos $CONTRACT_ADDRESS $UMEE_WALLET $UUMEE_AMOUNT_TO_SEND --eth-pk $ETH_PK --eth-rpc "${ETH_RPC}" -y &>> TXs_TO_COSMOS_LOG.txt
	if [ "$?" = "0" ]; then
		SS_TX_TO_COSMOS=$(($SS_TX_TO_COSMOS+1))
	else
		ERR_TX_TO_COSMOS=$(($ERR_TX_TO_COSMOS+1))
	fi
}

SS_TX_TO_ETH=0
SS_TX_TO_COSMOS=0
ERR_TX_TO_ETH=0
ERR_TX_TO_COSMOS=0

while true; do
if [ "$MODE" = "1" ] || [ "$MODE" = "3" ]; then
	if [ $SS_TX_TO_ETH -lt $TX_TO_ETH ]; then
		send_to_eth
	fi
fi
monitoring
sleep $DELAY_TIME
if [ "$MODE" = "2" ] || [ "$MODE" = "3" ]; then
	if [ $SS_TX_TO_COSMOS -lt $TX_TO_COSMOS ]; then
    if [ $CYCLE_SHIFT -gt 0 ] && [ "$MODE" = "3" ]; then
      CYCLE_SHIFT=$(($CYCLE_SHIFT-1))
    else
      send_to_cosmos
    fi
	fi
fi
monitoring
if [ "$SS_TX_TO_COSMOS" = "$TX_TO_COSMOS" ] && [ "$SS_TX_TO_ETH" = "$TX_TO_ETH" ]; then
  echo ""
  echo "Done!"
  break
fi
sleep $DELAY_TIME
done

