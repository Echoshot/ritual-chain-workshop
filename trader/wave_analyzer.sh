#!/bin/bash
WEBHOOK_URL="$DISCORD_WEBHOOK"
OPENROUTER_API_KEY="$OPENROUTER_API_KEY"

GOLD=$(curl -s "https://api.gold-api.com/price/XAU" | grep -o '"price":[0-9.]*' | cut -d':' -f2)
echo "Gold price fetched: $GOLD"

TODAY=$(date +%Y-%m-%d)
HISTORY_FILE="trader/gold_history.csv"

if [ ! -f "$HISTORY_FILE" ]; then
  echo "date,price" > "$HISTORY_FILE"
fi

if ! grep -q "^$TODAY," "$HISTORY_FILE"; then
  echo "$TODAY,$GOLD" >> "$HISTORY_FILE"
fi

HISTORY_DATA=$(tail -n 90 "$HISTORY_FILE")

python3 << PYEOF
import json, subprocess, os

gold = "$GOLD"
webhook = os.environ.get("DISCORD_WEBHOOK", "")
api_key = os.environ.get("OPENROUTER_API_KEY", "")

history_csv = """$HISTORY_DATA"""

prompt = f"""You are an expert Elliott Wave + SMC trader analyzing XAU/USD on the DAILY timeframe.

Historical daily closing prices (date,price):
{history_csv}

Current live price: {gold}

Apply strict Elliott Wave fractal rules:
- Each motive wave (1, 3, 5) must subdivide into a five-wave structure
- Each corrective wave (2, 4) must subdivide into a three-wave structure
- Wave 2 never retraces beyond the start of wave 1
- Wave 3 is never the shortest among waves 1, 3, 5
- Wave 4 does not overlap wave 1's price territory (except in diagonals)
- Identify the current wave count and degree based on available data
- If insufficient data exists for full degree count, state that clearly and give your best partial count

Give a concise but structured response with:
SETUP GRADE (A/B/C)
BIAS (Bullish/Bearish/Neutral)
WAVE COUNT (current wave label, e.g. Wave 3 of 5)
ENTRY
SL
TP1 TP2 TP3
REASONING (brief, max 3 sentences)
"""

payload = {
    "model": "openrouter/auto",
    "max_tokens": 1000,
    "messages": [{"role": "user", "content": prompt}]
}

result = subprocess.run(
    ["curl", "-s", "https://openrouter.ai/api/v1/chat/completions",
     "-H", f"Authorization: Bearer {api_key}",
     "-H", "Content-Type: application/json",
     "-d", json.dumps(payload)],
    capture_output=True, text=True
)

response = json.loads(result.stdout)
print("MODEL USED:", response.get("model", "unknown"))

if "choices" in response:
    analysis = response["choices"][0]["message"]["content"][:1800]
else:
    analysis = f"Error: {response.get('error', {}).get('message', str(response))}"

discord_payload = json.dumps({
    "content": f"**🥇 Gold Elliott Wave + SMC Analysis**\n💲 Live Price: \${gold}\n\n{analysis}"
})

subprocess.run(["curl", "-s", "-X", "POST", webhook,
                "-H", "Content-Type: application/json",
                "-d", discord_payload])
print("Posted!")
PYEOF

# Call on-chain contract to record signal
GOLD_PRICE_CLEAN=$(printf "%.2f" $GOLD)
python3 << PYEOF2
import os
from web3 import Web3
from eth_account import Account

private_key = os.environ.get("DEPLOYER_PRIVATE_KEY", "")
gold_price = "$GOLD_PRICE_CLEAN"
contract_addr = "0x0f31168ea1c03e807Af63198DE9e083Ccc644036"
rpc = "https://rpc.ritualfoundation.org"

if private_key:
    try:
        w3 = Web3(Web3.HTTPProvider(rpc))
        account = Account.from_key(private_key)
        abi = [{"inputs":[{"internalType":"string","name":"goldPrice","type":"string"}],"name":"requestSignal","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}]
        contract = w3.eth.contract(address=Web3.to_checksum_address(contract_addr), abi=abi)
        nonce = w3.eth.get_transaction_count(account.address)
        tx = contract.functions.requestSignal(gold_price).build_transaction({
            "from": account.address,
            "nonce": nonce,
            "gas": 500000,
            "maxFeePerGas": w3.to_wei("2", "gwei"),
            "maxPriorityFeePerGas": w3.to_wei("1", "gwei"),
            "chainId": 1979
        })
        signed = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        print(f"Signal sent on-chain! TX: {tx_hash.hex()}")
    except Exception as e:
        print(f"On-chain call note: {e}")
else:
    print("No private key - skipping on-chain call")
PYEOF2
