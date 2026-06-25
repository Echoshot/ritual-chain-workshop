#!/bin/bash
WEBHOOK_URL="$DISCORD_WEBHOOK"
OPENROUTER_API_KEY="$OPENROUTER_API_KEY"

GOLD=$(curl -s "https://api.coinbase.com/v2/prices/XAU-USD/spot" | grep -o '"amount":"[^"]*"' | cut -d'"' -f4)
echo "Gold price fetched: $GOLD"

ANALYSIS=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"google/gemma-4-31b-it:free\",\"messages\":[{\"role\":\"user\",\"content\":\"Analyze XAU gold price ${GOLD} using SMC. Give SETUP GRADE, BIAS, ENTRY, SL, TP, WAVE COUNT, REASON.\"}]}" \
  | jq -r '.choices[0].message.content')

echo "$ANALYSIS" > /tmp/analysis.txt

python3 -c "
import json, subprocess
gold = '$GOLD'
webhook = '$WEBHOOK_URL'
analysis = open('/tmp/analysis.txt').read()
analysis_short = analysis[:1800]; payload = json.dumps({'content': '**Gold Signal** Price: \$' + gold + '\n\n' + analysis_short})
subprocess.run(['curl','-s','-X','POST',webhook,'-H','Content-Type: application/json','-d',payload])
print('Posted!')
"
