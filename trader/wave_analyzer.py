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
                history += f"- {row[0]}: Price={row[1]}, Grade={row[2]}, WaveCount={row[9] if len(row) > 9 else 'N/A'}, Invalidation={row[11] if len(row) > 11 else 'N/A'}\n"

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
CORRECTION_STATUS: COMPLETE or IN PROGRESS.
- If IN PROGRESS: do not issue an entry. Set SETUP_GRADE to "No Setup" and state specifically what needs to happen for completion (e.g. wave (c) reaching equal length with wave (a), or price reclaiming a specific level).
- If COMPLETE: entry must be placed at or near the actual reversal point, with SL just beyond the correction'''s extreme -- not beyond the start of the prior impulse wave.
COUNT_CONSISTENCY: Check {history} for the most recent primary wave count and its ALT_INVALIDATION level before proposing a new one.
- If price has NOT closed beyond that invalidation level, retain the exact same primary wave count and wave number as the prior signal. Do not restate a new structure or renumber waves.
- Only propose a new primary count if the prior invalidation level was actually breached, and state explicitly: "Prior count invalidated at [level] -- new primary count established."
"""

r2 = requests.post("https://api.mistral.ai/v1/chat/completions",
    headers={"Authorization": f"Bearer {MISTRAL_KEY}", "Content-Type": "application/json"},
    json={"model": "mistral-small-latest", "max_tokens": 600,
          "messages": [{"role": "user", "content": prompt}]})

print("MISTRAL STATUS:", r2.status_code, "BODY:", r2.text[:1000])
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

from web3 import Web3

RPC_URL = "https://rpc.ritualfoundation.org"
CONTRACT_ADDRESS = "0xf5e6459F1BBB029625716d6590275B8B4d768B36"
PRIVATE_KEY = os.environ.get("PRIVATE_KEY")

def submit_onchain(gold_price):
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    with open("trader/gold_signal_abi.json") as f:
        abi = json.load(f)
    contract = w3.eth.contract(address=Web3.to_checksum_address(CONTRACT_ADDRESS), abi=abi)
    account = w3.eth.account.from_key(PRIVATE_KEY)
    tx = contract.functions.requestSignal(str(gold_price)).build_transaction({
        "from": account.address,
        "nonce": w3.eth.get_transaction_count(account.address),
        "gas": 300000,
        "maxFeePerGas": w3.eth.gas_price,
        "maxPriorityFeePerGas": w3.eth.gas_price,
        "chainId": 1979,
    })
    print("DEBUG TX:", tx)
    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f"On-chain tx sent: {tx_hash.hex()}")
    return tx_hash.hex()

submit_onchain(gold)
