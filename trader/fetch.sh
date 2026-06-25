#!/bin/bash

WEBHOOK_URL="https://discord.com/api/webhooks/1519528402527457382/YpiUYY98pFhGAkAqBilhP0fLTSuOc3auMEM3LDeYEldHKc54ZrnmDzPWbhnnSJhcmC99"

# BTC Price
BTC=$(curl -s "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT" | grep -o '"price":"[^"]*"' | cut -d'"' -f4)

# ETH Price
ETH=$(curl -s "https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT" | grep -o '"price":"[^"]*"' | cut -d'"' -f4)

# GOLD Price (fixed parser)
GOLD=$(curl -s "https://api.coinbase.com/v2/prices/XAU-USD/spot" | grep -o '"amount":"[^"]*"' | cut -d'"' -f4)

# Post to Discord
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"📊 **Market Prices**\n🟠 BTC: \$$BTC\n🔵 ETH: \$$ETH\n🟡 GOLD: \$$GOLD\"}"

echo "Posted to Discord!"
