const MasterchefActivityTwoDelegator = artifacts.require("ShardingDAOMiningDelegator");
const MasterchefActivityTwoDelegate = artifacts.require("ShardingDAOMiningDelegate");
const SHARDContract = artifacts.require("SHDToken");
const WethTokenContract = artifacts.require("WethToken");

module.exports = function (deployer) {
    let treasury = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57";
    deployer.deploy(MasterchefActivityTwoDelegate).then(function(){
        return deployer.deploy(MasterchefActivityTwoDelegator, SHARDContract.address, WethTokenContract.address, 
            SHARDContract.address, treasury, 10, 0, MasterchefActivityTwoDelegate.address, MasterchefActivityTwoDelegate.address);
      });
};