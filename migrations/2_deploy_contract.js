const RateSwitcher = artifacts.require("RateSwitcher");

//deploys an instance of our contract (RateSwitcher)
module.exports = function(deployer) {
  deployer.deploy(RateSwitcher);
};
