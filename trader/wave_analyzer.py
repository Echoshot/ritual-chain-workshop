import requests, os, csv, json
from datetime import datetime

WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK")
MISTRAL_KEY = os.environ.get("MISTRAL_API_KEY")
LOG_FILE = "trader/signal_log.csv"

history = ""
if os.path.exists(LOG_FILE):
    with open(LOG_FILE, "r") as f:
        rows = list(csv.reader(f))
        if len(rows) > 1:
            recent = rows[-7:]
            history = "Previous signals:\n"
            for row in recent:
                history += f"- {row[0]}: Price={row[1]}, Grade={row[2]}\n"

r = requests.get("https://api.coinbase.com/v2/prices/XAU-USD/spot")
gold = round(float(r.json()["data"]["amount"]), 2)
print(f"Gold price fetched: {gold}")

prompt = f"""You are an SMC and Elliott Wave trading agent analyzing XAU/USDT.

{history}

Current Gold price: {gold}

Based on price history and current price, give analysis:
SETUP_GRADE: A+ or B or No Setup
BIAS: Bullish or Bearish
ENTRY: price
SL: price
TP1: price
TP2: price
TP3: price
WAVE_COUNT: current wave estimate
REASONING: 2-3 sentences referencing previous signals if available
ALT_WAVE_COUNT: alternate wave estimate for primary count failure
ALT_INVALIDATION: price level where primary count fails
ALTERNATION_NOTE: one sentence on rule of alternation
"""

r2 = requests.post("https://api.mistral.ai/v1/chat/completions",
    headers={"Authorization": f"Bearer {MISTRAL_KEY}", "Content-Type": "application/json"},
    json={"model": "mistral-small-latest", "max_tokens": 600,
          "messages": [{"role": "user", "content": prompt}]})

analysis = r2.json()["choices"][0]["message"]["content"]
print("Analysis received")

def extract(text, key):
    for line in text.split("\n"):
        if key in line:
            return line.split(":")[-1].strip()
    return "N/A"

grade = extract(analysis, "SETUP_GRADE")
bias = extract(analysis, "BIAS")
entry = extract(analysis, "ENTRY")
sl = extract(analysis, "SL")
tp1 = extract(analysis, "TP1")
tp2 = extract(analysis, "TP2")
tp3 = extract(analysis, "TP3")
wave_count = extract(analysis, "WAVE_COUNT")
alt_wave = extract(analysis, "ALT_WAVE_COUNT")
alt_invalidation = extract(analysis, "ALT_INVALIDATION")
alternation_note = extract(analysis, "ALTERNATION_NOTE")

timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
file_exists = os.path.exists(LOG_FILE)
with open(LOG_FILE, "a", newline="") as f:
    writer = csv.writer(f)
    if not file_exists:
        writer.writerow(["timestamp","price","grade","bias","entry","sl","tp1","tp2","tp3",
                          "wave_count","alt_wave","alt_invalidation","alternation_note"])
    writer.writerow([timestamp, gold, grade, bias, entry, sl, tp1, tp2, tp3,
                      wave_count, alt_wave, alt_invalidation, alternation_note])

print(f"Signal logged: {grade} | {bias} | Entry: {entry}")

message = f"""🥇 **Gold Elliott Wave + SMC Signal**
Grade: {grade} | Bias: {bias}
Entry: {entry} | SL: {sl}
TP1: {tp1} | TP2: {tp2} | TP3: {tp3}
Wave Count: {wave_count}
Alt Count: {alt_wave}
Alt Invalidation: {alt_invalidation}
Alternation Note: {alternation_note}
"""
requests.post(WEBHOOK_URL, json={"content": message})
print("Posted!")
