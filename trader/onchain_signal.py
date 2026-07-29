import os, json
from web3 import Web3
from eth_account import Account

RPC = "https://rpc.ritualfoundation.org"
CONTRACT = "0x1D9618daa1f392c39E62712e8Fe69D41b2179F7E"
pk = os.environ.get("DEPLOYER_PRIVATE_KEY", "")
gold = os.environ.get("GOLD_PRICE", "4039.00")

w3 = Web3(Web3.HTTPProvider(RPC))
acct = Account.from_key(pk)

with open("/workspaces/ritual-chain-workshop/trader/gold_signal_abi.json") as f:
    abi = json.load(f)

contract = w3.eth.contract(
    address=Web3.to_checksum_address(CONTRACT), abi=abi)

nonce = w3.eth.get_transaction_count(acct.address)
tx = contract.functions.requestSignal(gold).build_transaction({
    "from": acct.address,
    "nonce": nonce,
    "gas": 500000,
    "maxFeePerGas": w3.to_wei("2", "gwei"),
    "maxPriorityFeePerGas": w3.to_wei("1", "gwei"),
    "chainId": 1979,
    "value": 0
})
signed = acct.sign_transaction(tx)
txh = w3.eth.send_raw_transaction(signed.raw_transaction)
print(f"On-chain TX: {txh.hex()}")
