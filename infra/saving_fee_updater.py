import os
import requests
from web3 import Web3
from datetime import datetime
from dotenv import load_dotenv

# --------------------
# LOAD ENV
# --------------------
load_dotenv()

PRIVATE_KEY = os.getenv("PRIVATE_KEY")
ACCOUNT_ADDRESS = os.getenv("ACCOUNT_ADDRESS")

# ABI (only the function we need)
CONTRACT_ABI = [
    {
        "inputs": [
            {"internalType": "uint256", "name": "_joinFee", "type": "uint256"},
            {"internalType": "uint256", "name": "_savingFee", "type": "uint256"},
        ],
        "name": "editFees",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    }
]

# RPC + contracts pulled from .env
CONTRACTS = {
    "base": {
        "rpc": "https://mainnet.base.org",
        "address": os.getenv("CONTRACT_BASE"),
    },
    "celo": {
        "rpc": "https://rpc.api.lisk.com",
        "address": os.getenv("CONTRACT_CELO"),
    }
}

# --------------------
# HELPERS
# --------------------
def get_eth_price_usd():
    """Fetch current ETH price in USD from CoinGecko"""
    url = "https://api.coingecko.com/api/v3/simple/price"
    resp = requests.get(url, params={"ids": "ethereum", "vs_currencies": "usd"})
    resp.raise_for_status()
    return resp.json()["ethereum"]["usd"]

def usd_to_wei(usd_amount, eth_price_usd):
    eth_value = usd_amount / eth_price_usd
    return int(eth_value * 10**18)

def update_saving_fee(chain_name, rpc_url, contract_addr, saving_fee_wei):
    """Call editFees on the contract for the given chain"""
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    if not w3.is_connected():
        raise RuntimeError(f"Could not connect to {chain_name} RPC")

    contract = w3.eth.contract(address=Web3.to_checksum_address(contract_addr), abi=CONTRACT_ABI)
    nonce = w3.eth.get_transaction_count(ACCOUNT_ADDRESS)

    txn = contract.functions.editFees(0, saving_fee_wei).build_transaction({
        "chainId": w3.eth.chain_id,
        "gas": 200000,
        "gasPrice": w3.eth.gas_price,
        "nonce": nonce,
    })

    signed_txn = w3.eth.account.sign_transaction(txn, private_key=PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    print(f"[{chain_name}] Tx sent: {tx_hash.hex()}")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    print(f"[{chain_name}] ✅ Tx confirmed in block {receipt.blockNumber}")

# --------------------
# MAIN
# --------------------
if __name__ == "__main__":
    eth_price = get_eth_price_usd()
    saving_fee_wei = usd_to_wei(1, eth_price)

    print(f"[{datetime.now()}] ETH Price: ${eth_price}, SavingFee: {saving_fee_wei} wei (~$1)")

    for chain, cfg in CONTRACTS.items():
        try:
            update_saving_fee(chain, cfg["rpc"], cfg["address"], saving_fee_wei)
        except Exception as e:
            print(f"[{chain}] ❌ Error: {e}")