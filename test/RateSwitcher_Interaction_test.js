//
const RateSwitcher = artifacts.require("RateSwitcher");
const LendingPool = artifacts.require("LendingPool");
const LendingPoolCore = artifacts.require("LendingPoolCore");
const LendingPoolAddressesProvider = artifacts.require("LendingPoolAddressesProvider");

///initialize web3 object
const Web3 = require('web3');
const web3 = new Web3(`https://kovan.infura.io/v3/344452915ed54c76a762b0eee4b66060`);

const lendingPoolAddressesProviderAddress = '0x9C6C63aA0cD4557d7aE6D9306C06C093A2e35408';

const lendingPoolAddressessProv = new web3.eth.Contract(LendingPoolAddressesProvider.abi, lendingPoolAddressesProviderAddress);

const lendingPoolAddress = lendingPoolAddressessProv.methods.getLendingPool();
const lendingPoolProv = new web3.eth.Contract(LendingPool.abi, lendingPoolAddress);

const lendingPoolCoreAddress = lendingPoolAddressessProv.methods.getLendingPoolCore();
const lendingPoolCoreProv = new web3.eth.Contract(LendingPoolCore.abi, lendingPoolCoreAddress);

const myAddress = '0xa3e1c2602f628112E591A10094bbD59BDC3cb512';


web3.eth.accounts.create();

contract("RateSwitcher", async()=>{
    it("should swap the interest Rates for all Reserves", async ()=>{
        
    })
})
