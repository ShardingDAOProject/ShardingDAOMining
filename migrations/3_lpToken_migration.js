const SjuneTokenContract = artifacts.require("SjuneToken");

module.exports = function (deployer) {
  deployer.deploy(SjuneTokenContract);
};

