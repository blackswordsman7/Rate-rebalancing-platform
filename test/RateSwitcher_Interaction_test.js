///
const RateSwitcher = artifacts.require('RateSwitcher');

///initialize web3 object
const Web3 = require('web3');
const web3 = new Web3(Web3.giveProvider || "ws://localhost:7545");

/// Retrieve LendingPool address
LendingPoolAddressesProvider provider = LendingPoolAddressesProvider(0x9C6C63aA0cD4557d7aE6D9306C06C093A2e35408);
LendingPool lendingPool = LendingPool(provider.getLendingPool());
