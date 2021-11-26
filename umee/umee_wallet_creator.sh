#!/bin/bash
read -p "Enter wallets name: " WALLETS_NAME
read -p "Enter wallets password: " WALLETS_PASSWORD
read -p "Enter desired wallets quantity: " NUM_WALLETS
echo "Starting..."
sleep 2
clear
CYCLE=0
for (( VAR = 0; VAR < $NUM_WALLETS; VAR++ )); do
	CYCLE=$(( $CYCLE + 1 ))
	echo -e "${WALLETS_PASSWORD}\n" | umeed keys add "${WALLETS_NAME}_$CYCLE" >> temp.txt
done
  cat temp.txt | grep -Eo "address: [a-zA-Z0-9]*" | cut -d : -f2 | cut -d ' ' -f2 >> wallets.txt
  rm -rf temp.txt
