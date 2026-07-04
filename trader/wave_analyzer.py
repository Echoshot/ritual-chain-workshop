import requests, os

WEBHOOK_URL = "https://discord.com/api/webhooks/1521479905139884084/S9XSwi_uNy42QKfYtRjix9irluaD2E6cUAvpruinBwx6_ecAB-nAp0nm4Geo1UbdJMpc"
MISTRAL_KEY = os.environ.get("MISTRAL_API_KEY", "")

# Fetch Gold price
r = requests.get("https://api.coinbase.com/v2/prices/XAU-USD/spot")
gold = round(float(r.json()["data"]["amount"]), 2)
print(f"Gold price fetched: {gold}")

# Get AI analysis
r2 = requests.post("https://api.mistral.ai/v1/chat/completions",
    headers={"Authorization": f"Bearer {MISTRAL_KEY}", "Content-Type": "application/json"},
    json={"model": "mistral-small-latest", "max_tokens": 500,
          "messages": [{"role": "user", "content": f"Gold price is {gold}. Give SMC Elliott Wave analysis: SETUP GRADE, BIAS, ENTRY, SL, TP1, TP2, TP3, WAVE COUNT, REASONING."}]})

analysis = r2.json()["choices"][0]["message"]["content"]
print("Analysis received")

# Post to Discord
requests.post(WEBHOOK_URL, json={"content": f"🏅 **Gold Elliott Wave + SMC Analysis**\n💲 Live Price: ${gold}\n\n{analysis}"})
print("Posted!")
