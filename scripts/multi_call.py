from brownie import *

from dotmap import DotMap

def main():
    return deploy()

def deploy():
    deployer = accounts[0]

    multi_call = Multicall.deploy({"from": deployer})

    return DotMap(
        multi_call=multi_call
    )

