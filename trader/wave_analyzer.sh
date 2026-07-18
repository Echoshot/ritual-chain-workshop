#!/bin/bash

WEBHOOK_URL="https://discord.com/api/webhooks/1521479905139884084/S9XSwi_uNy42QKfYtRjix9irluaD2E6cUAvpruinBwx6_ecAB-nAp0nm4Geo1UbdJMpc"

GOLD=$(curl -s "https://api.coinbase.com/v2/prices/XAU-USD/spot" | grep -o '"amount":"[^"]*"' | cut -d'"' -f4)
GOLD_CLEAN=$(printf "%.2f" $GOLD)
echo "Gold price fetched: $GOLD_CLEAN"

ANALYSIS=$(python3 << PYEOF
import requests, os, json

gold = "$GOLD_CLEAN"
api_key = os.environ.get("MISTRAL_API_KEY", "")

r = requests.post("https://api.mistral.ai/v1/chat/completions",
    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    json={"model": "mistral-small-latest", "max_tokens": 500,
          "messages": [{"role": "user", "content": f"Gold price is {gold}. Give SMC Elliott Wave analysis: SETUP GRADE, BIAS, ENTRY, SL, TP1, TP2, TP3, WAVE COUNT, REASONING."}]})

print(r.json()["choices"][0]["message"]["content"])
PYEOF
)

echo "Analysis received"

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"🏅 **Gold Elliott Wave + SMC Analysis**\n💲 Live Price: \$$GOLD_CLEAN\n\n$ANALYSIS\"}"

echo "Posted!"
