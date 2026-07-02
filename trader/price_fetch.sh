#!/bin/bash
WEBHOOK="https://discord.com/api/webhooks/1519528402527457382/YpiUYY98pFhGAkAqBilhP0fLTSuOc3auMEM3LDcYEldHKc54ZrnmD2PwbhnnSJhcmC99"
BTC=$(curl -s "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT" | grep -o '"price":"[^"]*"' | cut -d'"' -f4)
ETH=$(curl -s "https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT" | grep -o '"price":"[^"]*"' | cut -d'"' -f4)
XAU=$(curl -s "https://api.coinbase.com/v2/prices/XAU-USD/spot" | grep -o '"amount":"[^"]*"' | cut -d'"' -f4 | head -1)
XAU=$(printf "%.2f" $XAU)
BTC=$(printf "%.2f" $BTC)
ETH=$(printf "%.2f" $ETH)
curl -X POST "$WEBHOOK" -H "Content-Type: application/json" -d "{"content": "**MARKET UPDATE**\n🟠 BTC: \$$BTC\n🔵 ETH: \$$ETH\n🟡 GOLD: \$$XAU"}"
bash trader/wave_analyzer.sh
