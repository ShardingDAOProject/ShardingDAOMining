const SjuneTokenContract = artifacts.require("SjuneToken");
const Swap2Contract = artifacts.require("UniswapV2PairOfPool2");

const MasterchefDelegator = artifacts.require("ShardingDAOMiningDelegator");
const SHARDContract = artifacts.require("SHDToken");

contract('test delegator', (accounts) => {
    it('add three pool successfully', async () => {
        const accountOne = accounts[0];
        const accountTwo = accounts[1];
        const accountThree = accounts[2];
        const zeroAddress = "0x0000000000000000000000000000000000000000";

        const delegator = await MasterchefDelegator.deployed();
        const SHARD = await SHARDContract.deployed();
        await SHARD.addMiner(delegator.address);
        await delegator.setNftShard(accountOne);

        const Swap2 = await Swap2Contract.deployed();
        await delegator.add(0, Swap2.address, zeroAddress);
        await delegator.add(1, Swap2.address, zeroAddress);

        const juneInstance = await SjuneTokenContract.deployed();
        await delegator.acceptInvitation(delegator.address, { from: accountOne });
        await delegator.acceptInvitation(accountOne, { from: accountTwo });
        await delegator.acceptInvitation(accountTwo, { from: accountThree });

        await juneInstance.mint(accountOne, 100000);
        await juneInstance.approve(delegator.address, 90000, { from: accountOne });

        await juneInstance.mint(accountTwo, 100000);
        await juneInstance.approve(delegator.address, 90000, { from: accountTwo });

        await juneInstance.mint(accountThree, 100000);
        await juneInstance.approve(delegator.address, 90000, { from: accountThree });

        // let depositGasEstimate = await delegator.deposit.estimateGas(0, 1000, 1, { from: accountOne });
        // console.log(depositGasEstimate);
        await delegator.deposit(0, 10000, 1);

        // await delegator.deposit(1, 1000, 1, { from: accountOne });
        // await delegator.deposit(1, 1000, 1, { from: accountTwo });
        await juneInstance.mint(accountOne, 100000);
        await juneInstance.mint(accountOne, 100000);

        //await delegator.withdraw(0);
        let pendingSHARD = await delegator.pendingSHARD(0, accountOne);
        let pendingSHARDs = await delegator.pendingSHARDByPids([0], accountOne);
        console.log("pending is:" + pendingSHARD['0'] + "  potential is:" + pendingSHARD['1']);
        await delegator.transferAdmin(accountTwo);

        await delegator.setSHDPerBlock(100000, true, {from: accountTwo});
        await delegator.setMarketingFund(accountOne);
        let userInfo = await delegator.getUserInfoByPids([0],accountOne);
    });
});
