const MasterchefActivityOneDelegator = artifacts.require("MarketingMiningDelegator");
const MasterchefActivityOneDelegate = artifacts.require("MarketingMiningDelegate");

const SHARDContract = artifacts.require("SHDToken");
const InvitationContract = artifacts.require("Invitation");
const WethTokenContract = artifacts.require("WethToken");

module.exports = function (deployer) { 
    let treasury = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57";
    deployer.deploy(MasterchefActivityOneDelegate).then(function(){
        return deployer.deploy(MasterchefActivityOneDelegator, SHARDContract.address,
            InvitationContract.address, 0, 1000000, 10000, InvitationContract.address, treasury, WethTokenContract.address, MasterchefActivityOneDelegate.address, MasterchefActivityOneDelegate.address);
      });
};