import requests, os, csv, json
from datetime import datetime

WEBHOOK_URL = "https://discord.com/api/webhooks/1521479905139884084/S9XSwi_uNy42QKfYtRjix9irluaD2E6cUAvpruinBwx6_ecAB-nAp0nm4Geo1UbdJMpc"
MISTRAL_KEY = os.environ.get("MISTRAL_API_KEY", "")
LOG_FILE = "trader/signal_log.csv"

# Load last 7 signals for memory
history = ""
if os.path.exists(LOG_FILE):
    with open(LOG_FILE, "r") as f:
        rows = list(csv.reader(f))
        if len(rows) > 1:
            recent = rows[-7:]
            history = "Previous signals:\n"
            for row in recent:
                history += f"- {row[0]}: Price={row[1]}, Grade={row[2]}, Bias={row[3]}, Entry={row[4]}, SL={row[5]}, TP1={row[6]}\n"

# Fetch Gold price
r = requests.get("https://api.coinbase.com/v2/prices/XAU-USD/spot")
gold = round(float(r.json()["data"]["amount"]), 2)
print(f"Gold price fetched: {gold}")

# Get AI analysis with memory
prompt = f"""You are an SMC and Elliott Wave trading agent analyzing XAU/USD Gold.

{history}

Current Gold price: {gold}

Based on price history and current price, give analysis:
SETUP GRADE: A+ or B or No Setup
BIAS: Bullish or Bearish
ENTRY: price
SL: price
TP1: price
TP2: price
TP3: price
WAVE COUNT: current wave estimate
REASONING: 2-3 sentences referencing previous signals if available"""

r2 = requests.post("https://api.mistral.ai/v1/chat/completions",
    headers={"Authorization": f"Bearer {MISTRAL_KEY}", "Content-Type": "application/json"},
    json={"model": "mistral-small-latest", "max_tokens": 600,
          "messages": [{"role": "user", "content": prompt}]})

analysis = r2.json()["choices"][0]["message"]["content"]
print("Analysis received")

# Parse key fields from analysis
def extract(text, key):
    for line in text.split("\n"):
        if key in line:
            return line.split(":")[-1].strip()
    return "N/A"

grade = extract(analysis, "SETUP GRADE")
bias = extract(analysis, "BIAS")
entry = extract(analysis, "ENTRY")
sl = extract(analysis, "SL")
tp1 = extract(analysis, "TP1")

# Save to signal log
timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
file_exists = os.path.exists(LOG_FILE)
with open(LOG_FILE, "a", newline="") as f:
    writer = csv.writer(f)
    if not file_exists:
        writer.writerow(["timestamp","price","grade","bias","entry","sl","tp1"])
    writer.writerow([timestamp, gold, grade, bias, entry, sl, tp1])

print(f"Signal logged: {grade} | {bias} | Entry: {entry}")

# Post to Discord
requests.post(WEBHOOK_URL, json={"content": f"🏅 **Gold Elliott Wave + SMC Analysis**\n💲 Live Price: ${gold}\n\n{analysis}"})
print("Posted!")
