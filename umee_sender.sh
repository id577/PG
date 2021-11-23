#!/bin/bash
VAL_ADDRESS="umeevaloper1wju82lrr8e5689rh5qum3n6ncjzrkyzfshuqkd"
SOURCE_WALLET="umee1vlm35w9h2lcdwzwn3zxs7ct5w5ud8fx8gaqnl4"
SOURCE_WALLET_PASSWORD=""
TARGET_WALLETS=(
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

