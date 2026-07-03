#!/bin/bash

WEBHOOK_URL="https://discord.com/api/webhooks/1521479905139884084/S9XSwi_uNy42QKfYtRjix9irluaD2E6cUAvpruinBwx6_ecAB-nAp0nm4Geo1UbdJMpc"
GEMINI_KEY="${GEMINI_API_KEY}"
OPENROUTER_KEY="${OPENROUTER_API_KEY}"

GOLD=$(curl -s "https://api.coinbase.com/v2/prices/XAU-USD/spot" | grep -o '"amount":"[^"]*"' | cut -d'"' -f4)
GOLD_CLEAN=$(printf "%.2f" $GOLD)
echo "Gold price fetched: $GOLD_CLEAN"

RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"contents\":[{\"parts\":[{\"text\":\"You are an SMC and Elliott Wave trader. Gold price: $GOLD_CLEAN. Give: SETUP GRADE: B or A+, BIAS: Bullish/Bearish, ENTRY, SL, TP1 TP2 TP3, WAVE COUNT, REASONING in 2 sentences.\"}]}]}")

ANALYSIS=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['candidates'][0]['content']['parts'][0]['text'])" 2>/dev/null || echo "Analysis unavailable")

echo "Analysis received"

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"🏅 **Gold Elliott Wave + SMC Analysis**\n💲 Live Price: \$$GOLD_CLEAN\n\n$ANALYSIS\"}"

echo "Posted!"

PRIVATE_KEY="${DEPLOYER_PRIVATE_KEY}"
if [ -n "$PRIVATE_KEY" ]; then
python3 << PYEOF
import os
from web3 import Web3
from eth_account import Account

pk = os.environ.get("DEPLOYER_PRIVATE_KEY","")
price = "$GOLD_CLEAN"
addr = "0x0f31168ea1c03e807Af63198DE9e083Ccc644036"
w3 = Web3(Web3.HTTPProvider("https://rpc.ritualfoundation.org"))
acct = Account.from_key(pk)
abi = [{"inputs":[{"internalType":"string","type":"string"}],"name":"requestSignal","outputs":[{"internalType":"uint256","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}]
contract = w3.eth.contract(address=Web3.to_checksum_address(addr),abi=abi)
nonce = w3.eth.get_transaction_count(acct.address)
tx = contract.functions.requestSignal(price).build_transaction({"from":acct.address,"nonce":nonce,"gas":500000,"maxFeePerGas":w3.to_wei("2","gwei"),"maxPriorityFeePerGas":w3.to_wei("1","gwei"),"chainId":1979})
signed = acct.sign_transaction(tx)
txh = w3.eth.send_raw_transaction(signed.raw_transaction)
print(f"On-chain TX: {txh.hex()}")
PYEOF
fi
