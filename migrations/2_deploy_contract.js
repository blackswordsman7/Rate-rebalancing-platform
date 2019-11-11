const RateSwitcher = artifacts.require("RateSwitcher");
const RateAdvisorPlatform = artifacts.require("RateAdvisorPlatform");
const LendingPoolAddressesProvider = artifacts.require("LendingPoolAddressesProvider");
const CoreLibrary = artifacts.require("CoreLibrary");
const LogLibrary = artifacts.require("LogLibrary");

const Web3 = require('web3');
const web3 = new Web3(`https://kovan.infura.io/v3/344452915ed54c76a762b0eee4b66060`);

//deploys an instance of our contract (RateSwitcher)
module.exports = function(deployer){
    //deployer.deploy(LendingPoolAddressesProvider);
    deployer.deploy(CoreLibrary);
    deployer.deploy(LogLibrary);
    deployer.link(CoreLibrary, RateSwitcher, RateAdvisorPlatform);
    deployer.link(LogLibrary, RateAdvisorPlatform);
    deployer.deploy(RateSwitcher, {gas: 4612388, from: '0xa3e1c2602f628112E591A10094bbD59BDC3cb512'});
    deployer.deploy(RateAdvisorPlatform, {gas: 4612388, from: '0xa3e1c2602f628112E591A10094bbD59BDC3cb512'});
};
