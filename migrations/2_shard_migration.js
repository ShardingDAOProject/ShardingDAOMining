const SHARDContract = artifacts.require("SHDToken");
const WethTokenContract = artifacts.require("WethToken");

module.exports = function (deployer) {
  deployer.deploy(WethTokenContract);
  deployer.deploy(SHARDContract);
};
