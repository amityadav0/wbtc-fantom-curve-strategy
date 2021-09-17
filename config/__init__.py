## Ideally, they have one file with the settings for the strat and deployment
## This file would allow them to configure so they can test, deploy and interact with the strategy

BADGER_DEV_MULTISIG = "0x8421Ec17f2535AD895e1DEdEA966D9F39B224eB3"

WANT = "0x5B5CFE992AdAC0C9D48E05854B2d91C73a003858" ##  Fantom Curve.fi WBTC/renBTC (btcCRV)
LP_COMPONENT = "0xbdff0c27dd073c119ebcb1299a68a6a92ae607f0"  ## Gauge lp token
REWARD_TOKEN = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83"  ## AAVE Token

PROTECTED_TOKENS = [WANT, LP_COMPONENT, REWARD_TOKEN]
## Fees in Basis Points
DEFAULT_GOV_PERFORMANCE_FEE = 1000
DEFAULT_PERFORMANCE_FEE = 1000
DEFAULT_WITHDRAWAL_FEE = 50

FEES = [DEFAULT_GOV_PERFORMANCE_FEE, DEFAULT_PERFORMANCE_FEE, DEFAULT_WITHDRAWAL_FEE]

REGISTRY = "0xFda7eB6f8b7a9e9fCFd348042ae675d1d652454f"  # Multichain BadgerRegistry
