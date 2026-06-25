#!/bin/bash

WEBHOOK="https://discord.com/api/webhooks/1519528402527457382/YpiUYY98pFhGAkAqBilhP0fLTSuOc3auMEM3LDeYEldHKc54ZrnmDzPWbhnnSJhcmC99"

BTC=$(curl -s "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT" | grep -o '"price":"[^"]*"' | cut -d'"' -f4)
ETH=$(curl -s "https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT" | grep -o '"price":"[^"]*"' | cut -d'"' -f4)
XAU=$(curl -s "https://api.binance.com/api/v3/ticker/price?symbol=XAUUSDT" | grep -o '"price":"[^"]*"' | cut -d'"' -f4)

curl -X POST "$WEBHOOK" \
-H "Content-Type: application/json" \
-d "{\"content\":\"📊 **MARKET UPDATE**\n🟠 BTC: \$$BTC\n🔵 ETH: \$$ETH\n🟡 GOLD: \$$XAU\"}"
