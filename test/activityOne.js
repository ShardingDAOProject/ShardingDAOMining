const testContract = artifacts.require("MarketingMiningDelegator");
const SHARDContract = artifacts.require("SHDToken");
const InvitationContract = artifacts.require("Invitation");

const SjuneTokenContract = artifacts.require("SjuneToken");
const Swap2Contract = artifacts.require("UniswapV2PairOfPool2");
const WethTokenContract = artifacts.require("WethToken");

contract('master chef', (accounts) => {
    it('add three pool successfully', async () => {
        const testfInstance = await testContract.deployed();
        const SHARDInstance = await SHARDContract.deployed();
        const ethInstance = await WethTokenContract.deployed();
        const invitationInstance = await InvitationContract.deployed();
        const juneInstance = await SjuneTokenContract.deployed();
        const zeroAddress = "0x0000000000000000000000000000000000000000";
        const accountOne = accounts[0];
        console.log(accountOne);
        const accountTwo = accounts[1];

        await invitationInstance.setActivityOne(testfInstance.address);
        await invitationInstance.setlpToken(juneInstance.address);

        let mintNts = 10000000000000;
        await SHARDInstance.addMiner(accountOne);
        await SHARDInstance.mint(accountOne, mintNts);
        await SHARDInstance.approve(testfInstance.address, mintNts);
        await testfInstance.addAvailableDividend(mintNts, true);

        await testfInstance.add(1, Swap2Contract.address, true);
        await testfInstance.add(2, Swap2Contract.address, true);
        await testfInstance.add(1, Swap2Contract.address, true);
        await testfInstance.add(4, ethInstance.address, true);
        await invitationInstance.acceptInvitation(accountTwo);
        await testfInstance.depositETH(3, { value: 10});
        await testfInstance.withdrawETH(3, 10);

        let zeroPool = await testfInstance.poolInfo(0);
        console.log("!!!!! last dividend height is " + zeroPool.lastDividendHeight);
        await testfInstance.setStartBlock(1);
        zeroPool = await testfInstance.poolInfo(0);
        console.log("!!!!! last dividend height is " + zeroPool.lastDividendHeight);

        await testfInstance.setIsDepositAvailable(true);
        await invitationInstance.acceptInvitation(testfInstance.address, {from: accountTwo});
        
        await juneInstance.mint(accountOne, 10000000);
        await juneInstance.approve(testfInstance.address, 9000000, { from: accountOne });

        await juneInstance.mint(accountTwo, 10000000);
        await juneInstance.approve(testfInstance.address, 9000000, { from: accountTwo });

        await juneInstance.mint(invitationInstance.address, 10000000);
        await invitationInstance.approve(testfInstance.address, 9000000);
        await invitationInstance.buildMyselfInvitation();
        await invitationInstance.deposit(0, 1000);

        await testfInstance.setSHDPerBlock(1000000000, false);
        let blockNum = await invitationInstance.getBlockNum();
        console.log("ji qiang ci start block: " + blockNum);
        await testfInstance.massUpdatePools(); 
        await testfInstance.massUpdatePools(); 
        await testfInstance.massUpdatePools(); 
        await testfInstance.massUpdatePools(); 
        await testfInstance.massUpdatePools(); 
        let contractPending = await testfInstance.pendingSHARD(0, invitationInstance.address);
        let contractPendings = await testfInstance.pendingSHARDByPids([0], invitationInstance.address);
        let poolInfo = await testfInstance.getPoolInfo(0);
        //console.log(contractPending);
        console.log("poolInfo   =========   lptoken amount is :" + poolInfo._tokenAmount + " accumulativeDividend: " + poolInfo._accumulativeDividend + " _usersTotalWeight Weight: " + poolInfo._usersTotalWeight + " _accs: " + poolInfo._accs);
        console.log("ji qiang pending block : " + contractPending['1'] + " ji qiang pending: " + contractPending['0']);
        console.log("====================");

        await testfInstance.deposit(0, 10000);
        await testfInstance.massUpdatePools(); 
        let userInfo = await testfInstance.userInfo(0, accountOne);
        let userInfos = await testfInstance.getUserInfoByPids([0],accountOne);
        poolInfo = await testfInstance.getPoolInfo(0);
        let bal = await SHARDInstance.balanceOf(testfInstance.address);
        console.log("deposit block height :" + blockNum + "  =============================");
        console.log("account one=========   amount is :" + userInfo.amount + " origin weight: " + userInfo.originWeight + " modified Weight: " + userInfo.modifiedWeight + " revenue :" + userInfo.revenue + " rewardDebt: " + userInfo.rewardDebt + " withdrawnState: " + userInfo.withdrawnState);
        //console.log("account two invitee weight = " + user2Invitee);
        console.log("poolInfo   =========   lptoken amount is :" + poolInfo._tokenAmount + " accumulativeDividend: " + poolInfo._accumulativeDividend + " _usersTotalWeight Weight: " + poolInfo._usersTotalWeight + " _accs: " + poolInfo._accs);
        console.log("test instance address shard token balance: " + bal);

        await testfInstance.massUpdatePools(); 
        blockNum = await invitationInstance.getBlockNum();
        await testfInstance.withdraw(0, 0);
        await testfInstance.massUpdatePools(); 
        userInfo = await testfInstance.userInfo(0, accountOne);
        poolInfo = await testfInstance.getPoolInfo(0);
        bal = await SHARDInstance.balanceOf(testfInstance.address);
        console.log("withdraw block height :" + blockNum + "  =============================");
        console.log("account one=========   amount is :" + userInfo.amount + " origin weight: " + userInfo.originWeight + " modified Weight: " + userInfo.modifiedWeight + " revenue :" + userInfo.revenue + " rewardDebt: " + userInfo.rewardDebt + " withdrawnState: " + userInfo.withdrawnState);
        //console.log("account two invitee weight = " + user2Invitee);
        console.log("poolInfo   =========   lptoken amount is :" + poolInfo._tokenAmount + " accumulativeDividend: " + poolInfo._accumulativeDividend + " _usersTotalWeight Weight: " + poolInfo._usersTotalWeight + " _accs: " + poolInfo._accs);
        console.log("test instance address shard token balance: " + bal);

        await testfInstance.massUpdatePools(); 
        await testfInstance.massUpdatePools();
        await testfInstance.massUpdatePools();
        blockNum = await invitationInstance.getBlockNum();
        await testfInstance.withdraw(0, 10000);
        await testfInstance.massUpdatePools(); 
        userInfo = await testfInstance.userInfo(0, accountOne);
        poolInfo = await testfInstance.getPoolInfo(0);
        bal = await SHARDInstance.balanceOf(testfInstance.address);
        console.log("withdraw block height :" + blockNum + "  =============================");
        console.log("account one=========   amount is :" + userInfo.amount + " origin weight: " + userInfo.originWeight + " modified Weight: " + userInfo.modifiedWeight + " revenue :" + userInfo.revenue + " rewardDebt: " + userInfo.rewardDebt + " withdrawnState: " + userInfo.withdrawnState);
        //console.log("account two invitee weight = " + user2Invitee);
        console.log("poolInfo   =========   lptoken amount is :" + poolInfo._tokenAmount + " accumulativeDividend: " + poolInfo._accumulativeDividend + " _usersTotalWeight Weight: " + poolInfo._usersTotalWeight + " _accs: " + poolInfo._accs);
        console.log("test instance address shard token balance: " + bal);

        blockNum = await invitationInstance.getBlockNum();
        await testfInstance.deposit(0, 10000);
        await testfInstance.massUpdatePools(); 
        userInfo = await testfInstance.userInfo(0, accountOne);
        poolInfo = await testfInstance.getPoolInfo(0);
        bal = await SHARDInstance.balanceOf(testfInstance.address);
        console.log("deposit block height :" + blockNum + "  =============================");
        console.log("account one=========   amount is :" + userInfo.amount + " origin weight: " + userInfo.originWeight + " modified Weight: " + userInfo.modifiedWeight + " revenue :" + userInfo.revenue + " rewardDebt: " + userInfo.rewardDebt + " withdrawnState: " + userInfo.withdrawnState);
        //console.log("account two invitee weight = " + user2Invitee);
        console.log("poolInfo   =========   lptoken amount is :" + poolInfo._tokenAmount + " accumulativeDividend: " + poolInfo._accumulativeDividend + " _usersTotalWeight Weight: " + poolInfo._usersTotalWeight + " _accs: " + poolInfo._accs);
        console.log("test instance address shard token balance: " + bal);

        await testfInstance.massUpdatePools(); 
        blockNum = await invitationInstance.getBlockNum();
        await testfInstance.withdraw(0, 0);
        await testfInstance.massUpdatePools(); 
        userInfo = await testfInstance.userInfo(0, accountOne);
        poolInfo = await testfInstance.getPoolInfo(0);
        bal = await SHARDInstance.balanceOf(testfInstance.address);
        console.log("withdraw block height :" + blockNum + "  =============================");
        console.log("account one=========   amount is :" + userInfo.amount + " origin weight: " + userInfo.originWeight + " modified Weight: " + userInfo.modifiedWeight + " revenue :" + userInfo.revenue + " rewardDebt: " + userInfo.rewardDebt + " withdrawnState: " + userInfo.withdrawnState);
        //console.log("account two invitee weight = " + user2Invitee);
        console.log("poolInfo   =========   lptoken amount is :" + poolInfo._tokenAmount + " accumulativeDividend: " + poolInfo._accumulativeDividend + " _usersTotalWeight Weight: " + poolInfo._usersTotalWeight + " _accs: " + poolInfo._accs);
        console.log("test instance address shard token balance: " + bal);

        await testfInstance.massUpdatePools(); 
        await testfInstance.massUpdatePools();
        await testfInstance.massUpdatePools();
        blockNum = await invitationInstance.getBlockNum();
        await testfInstance.withdraw(0, 10000);
        await testfInstance.massUpdatePools(); 
        userInfo = await testfInstance.userInfo(0, accountOne);
        poolInfo = await testfInstance.getPoolInfo(0);
        bal = await SHARDInstance.balanceOf(testfInstance.address);
        console.log("withdraw block height :" + blockNum + "  =============================");
        console.log("account one=========   amount is :" + userInfo.amount + " origin weight: " + userInfo.originWeight + " modified Weight: " + userInfo.modifiedWeight + " revenue :" + userInfo.revenue + " rewardDebt: " + userInfo.rewardDebt + " withdrawnState: " + userInfo.withdrawnState);
        //console.log("account two invitee weight = " + user2Invitee);
        console.log("poolInfo   =========   lptoken amount is :" + poolInfo._tokenAmount + " accumulativeDividend: " + poolInfo._accumulativeDividend + " _usersTotalWeight Weight: " + poolInfo._usersTotalWeight + " _accs: " + poolInfo._accs);
        console.log("test instance address shard token balance: " + bal);

        bal = await SHARDInstance.balanceOf(accountOne);
        console.log("account one withdraw shard: " + bal);
        await testfInstance.setIsRevenueWithdrawable(true);
        await testfInstance.withdraw(0, 0);
        bal = await SHARDInstance.balanceOf(accountOne);
        console.log("after set switch, account one withdraw shard: " + bal);

        await testfInstance.transferAdmin(accountTwo);
        await testfInstance.setAllocationPoint(0, 10, true, {from : accountTwo});
        await testfInstance.setMarketingFund(accountOne);
    });
});
