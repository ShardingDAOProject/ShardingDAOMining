
const Swap2Contract = artifacts.require("UniswapV2PairOfPool2");
const WethTokenContract = artifacts.require("WethToken");
const InvitationContract = artifacts.require("Invitation");

module.exports = function (deployer) {
    deployer.deploy(Swap2Contract, WethTokenContract.address);
    deployer.deploy(InvitationContract);
};