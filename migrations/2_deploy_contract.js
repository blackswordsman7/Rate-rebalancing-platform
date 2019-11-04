const RateSwitcher = artifacts.require("RateSwitcher");
const LendingPoolAddressesProvider = artifacts.require("LendingPoolAddressesProvider")

/// Retrieve LendingPool address
//LendingPoolAddressesProvider provider = LendingPoolAddressesProvider(0x9C6C63aA0cD4557d7aE6D9306C06C093A2e35408);
//LendingPool lendingPool = LendingPool(provider.getLendingPool());

//deploys an instance of our contract (RateSwitcher)
module.exports = function(deployer) {
    //deployer.deploy(LendingPoolAddressesProvider);
    deployer.deploy(RateSwitcher);
};
