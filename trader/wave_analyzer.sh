#!/bin/bash
WEBHOOK_URL="$DISCORD_WEBHOOK"
OPENROUTER_API_KEY="$OPENROUTER_API_KEY"

GOLD=$(curl -s "https://api.coinbase.com/v2/prices/XAU-USD/spot" | grep -o '"amount":"[^"]*"' | cut -d'"' -f4)
echo "Gold price fetched: $GOLD"

python3 << PYEOF
import json, subprocess, os

gold = "$GOLD"
webhook = os.environ.get("DISCORD_WEBHOOK", "")
api_key = os.environ.get("OPENROUTER_API_KEY", "")

payload = {
    "model": "openrouter/auto",
    "max_tokens": 1000,
    "messages": [{
        "role": "user",
        "content": f"You are an SMC trader. XAU/USD live price is {gold}. Give: SETUP GRADE, BIAS, ENTRY, SL, TP1 TP2 TP3, WAVE COUNT, REASONING. Be concise."
    }]
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
    "content": f"**🥇 Gold SMC Analysis**\n💲 Live Price: \${gold}\n\n{analysis}"
})

subprocess.run(["curl", "-s", "-X", "POST", webhook,
                "-H", "Content-Type: application/json",
                "-d", discord_payload])
print("Posted!")
PYEOF
