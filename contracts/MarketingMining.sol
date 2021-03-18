// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "./ActivityBase.sol";
import "../interfaces/IInvitation.sol";

contract MarketingMining is ActivityBase{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How much token the user has provided.
        uint256 originWeight; //initial weight
        uint256 modifiedWeight; //take the invitation relationship into consideration.
        uint256 revenue;
        uint256 userDividend;
        uint256 devDividend;
        uint256 marketingFundDividend;
        uint256 rewardDebt; // Reward debt. See explanation below.
        bool withdrawnState;
        bool isUsed;
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 tokenAmount;  // lock amount
        IERC20 token;   // uniswapPair contract
        uint256 allocPoint;
        uint256 accumulativeDividend;
        uint256 lastDividendHeight;  // last dividend block height
        uint256 accShardPerWeight;
        uint256 totalWeight;
    }

    uint256 public constant BONUS_MULTIPLIER = 10;
    // The SHARD TOKEN!
    IERC20 public SHARD;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => uint256)) public userInviteeTotalAmount; // total invitee weight
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Total allocation poitns. Must be the sum of all allocation poishard in all pools.
    uint256 public totalAllocPoint = 0;
    // SHARD tokens created per block.
    uint256 public SHDPerBlock = 1 * (1e18);

    //get invitation relationship
    IInvitation public invitation;

    uint256 public bonusEndBlock;
    uint256 public totalAvailableDividend;
    
    bool public isInitialized;
    bool public isDepositAvailable;
    bool public isRevenueWithdrawable;

    event AddPool(uint256 indexed pid, address tokenAddress);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, uint256 weight);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    function initialize(
        IERC20 _SHARD,
        IInvitation _invitation,
        uint256 _bonusEndBlock,
        uint256 _startBlock, 
        uint256 _SHDPerBlock,
        address _developerDAOFund,
        address _marketingFund,
        address _weth
    ) public virtual onlyOwner{
        require(!isInitialized, "contract has been initialized");
        invitation = _invitation;
        bonusEndBlock = _bonusEndBlock;
        if (_startBlock < block.number) {
            startBlock = block.number;
        } else {
            startBlock = _startBlock;
        }
        SHARD = _SHARD;
        developerDAOFund = _developerDAOFund;
        marketingFund = _marketingFund;
        WETHToken = _weth;
        if(_SHDPerBlock > 0){
            SHDPerBlock = _SHDPerBlock;
        }
        userDividendWeight = 4;
        devDividendWeight = 1;

        amountFeeRateNumerator = 1;
        amountfeeRateDenominator = 5;

        contractFeeRateNumerator = 1;
        contractFeeRateDenominator = 5;
        isDepositAvailable = true;
        isRevenueWithdrawable = false;
        isInitialized = true;
    }

    // Add a new pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _tokenAddress, bool _withUpdate) public virtual {
        checkAdmin();
        if(_withUpdate){
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        PoolInfo memory newpool = PoolInfo({
            token: _tokenAddress, 
            tokenAmount: 0,
            allocPoint: _allocPoint,
            lastDividendHeight: lastRewardBlock,
            accumulativeDividend: 0,
            accShardPerWeight: 0,
            totalWeight: 0
        });
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(newpool);
        emit AddPool(poolInfo.length.sub(1), address(_tokenAddress));
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function setAllocationPoint(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public virtual {
        checkAdmin();
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setSHDPerBlock(uint256 _SHDPerBlock, bool _withUpdate) public virtual {
        checkAdmin();
        if (_withUpdate) {
            massUpdatePools();
        }
        SHDPerBlock = _SHDPerBlock;
    }

    function setIsDepositAvailable(bool _isDepositAvailable) public virtual onlyOwner {
        isDepositAvailable = _isDepositAvailable;
    }

    function setIsRevenueWithdrawable(bool _isRevenueWithdrawable) public virtual onlyOwner {
        isRevenueWithdrawable = _isRevenueWithdrawable;
    }

    // update reward vairables for pools. Be careful of gas spending!
    function massUpdatePools() public virtual {
        uint256 poolCount = poolInfo.length;
        for(uint256 i = 0; i < poolCount; i ++){
            updatePoolDividend(i);
        }
    }

    function addAvailableDividend(uint256 _amount, bool _withUpdate) public virtual {
        if(_withUpdate){
            massUpdatePools();
        }
        SHARD.safeTransferFrom(address(msg.sender), address(this), _amount);
        totalAvailableDividend = totalAvailableDividend.add(_amount);
    }

    // update reward vairables for a pool
    function updatePoolDividend(uint256 _pid) public virtual {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastDividendHeight) {
            return;
        }
        if (pool.tokenAmount == 0) {
            pool.lastDividendHeight = block.number;
            return;
        }
        uint256 availableDividend = totalAvailableDividend;
        uint256 multiplier = getMultiplier(pool.lastDividendHeight, block.number);
        uint256 producedToken = multiplier.mul(SHDPerBlock);
        producedToken = availableDividend > producedToken? producedToken: availableDividend;
        if(totalAllocPoint > 0){
            uint256 poolDevidend = producedToken.mul(pool.allocPoint).div(totalAllocPoint);
            if(poolDevidend > 0){
                totalAvailableDividend = totalAvailableDividend.sub(poolDevidend);
                pool.accumulativeDividend = pool.accumulativeDividend.add(poolDevidend);
                pool.accShardPerWeight = pool.accShardPerWeight.add(poolDevidend.mul(1e12).div(pool.totalWeight));
            } 
        }
        pool.lastDividendHeight = block.number;
    }

    function depositETH(uint256 _pid) external payable virtual {
        require(address(poolInfo[_pid].token) == WETHToken, "invalid token");
        updateAfterDeposit(_pid, msg.value);
    }

    function withdrawETH(uint256 _pid, uint256 _amount) external virtual {
        require(address(poolInfo[_pid].token) == WETHToken, "invalid token");
        updateAfterwithdraw(_pid, _amount);
        if(_amount > 0){
            (bool success, ) = msg.sender.call{value: _amount}(new bytes(0));
            require(success, "Transfer: ETH_TRANSFER_FAILED");
        }
    }

    function updateAfterDeposit(uint256 _pid, uint256 _amount) internal{
        require(isDepositAvailable, "new invest is forbidden");
        require(_amount > 0, "invalid amount");
        (address invitor, , bool isWithdrawn) = invitation.getInvitation(msg.sender);
        require(invitor != address(0), "should be accept invitation firstly");
        updatePoolDividend(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        UserInfo storage userInvitor = userInfo[_pid][invitor];
        uint256 existedAmount = user.amount;
        bool withdrawnState = user.withdrawnState;
        if(!user.isUsed){
            user.isUsed = true;
            judgeContractSender(_pid);
            withdrawnState = isWithdrawn;
        }
        if(!withdrawnState && userInvitor.amount > 0){
            updateUserRevenue(userInvitor, pool);
        }
        if(!withdrawnState){
            updateInvitorWeight(msg.sender, invitor, _pid, true, _amount, isWithdrawn, withdrawnState);
        }

        if(existedAmount > 0){ 
            updateUserRevenue(user, pool);
        }

        updateUserWeight(msg.sender, _pid, true, _amount, isWithdrawn);
        if(!withdrawnState && userInvitor.amount > 0){
            userInvitor.rewardDebt = userInvitor.modifiedWeight.mul(pool.accShardPerWeight).div(1e12);
        }  
        if(!withdrawnState){
            user.withdrawnState = isWithdrawn;
        }
        user.amount = existedAmount.add(_amount);
        user.rewardDebt = user.modifiedWeight.mul(pool.accShardPerWeight).div(1e12);
        pool.tokenAmount = pool.tokenAmount.add(_amount);
        emit Deposit(msg.sender, _pid, _amount, user.modifiedWeight);
    }

    // Deposit tokens to marketing mining for SHD allocation.
    function deposit(uint256 _pid, uint256 _amount) public virtual {
        require(address(poolInfo[_pid].token) != WETHToken, "invalid pid");
        IERC20(poolInfo[_pid].token).safeTransferFrom(address(msg.sender), address(this), _amount);
        updateAfterDeposit(_pid, _amount);
    }

    // Withdraw tokens from marketMining.
    function withdraw(uint256 _pid, uint256 _amount) public virtual {
        require(address(poolInfo[_pid].token) != WETHToken, "invalid pid");
        IERC20(poolInfo[_pid].token).safeTransfer(address(msg.sender), _amount);
        updateAfterwithdraw(_pid, _amount);
    }

    function updateAfterwithdraw(uint256 _pid, uint256 _amount) internal {
        (address invitor, , bool isWithdrawn) = invitation.getInvitation(msg.sender);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        bool withdrawnState = user.withdrawnState;
        uint256 existedAmount = user.amount;
        require(existedAmount >= _amount, "withdraw: not good");
        updatePoolDividend(_pid);
        uint256 pending = updateUserRevenue(user, pool);
        UserInfo storage userInvitor = userInfo[_pid][invitor];
        if(!withdrawnState && userInvitor.amount > 0){
            updateUserRevenue(userInvitor, pool);
        }
        if(!withdrawnState){
            updateInvitorWeight(msg.sender, invitor, _pid, false, _amount, isWithdrawn, withdrawnState);
        }
        updateUserWeight(msg.sender, _pid, false, _amount, isWithdrawn);
        user.amount = existedAmount.sub(_amount);
        user.rewardDebt = user.modifiedWeight.mul(pool.accShardPerWeight).div(1e12);
        user.withdrawnState = isWithdrawn;
        if(!withdrawnState && userInvitor.amount > 0){
            userInvitor.rewardDebt = userInvitor.modifiedWeight.mul(pool.accShardPerWeight).div(1e12);
        }
        pool.tokenAmount = pool.tokenAmount.sub(_amount);
        user.revenue = 0;
        bool isContractSender = isUserContractSender[_pid][msg.sender];
        (uint256 marketingFundDividend, uint256 devDividend, uint256 userDividend) = calculateDividend(pending, _pid, existedAmount, isContractSender);
        user.userDividend = user.userDividend.add(userDividend);
        user.devDividend = user.devDividend.add(devDividend);
        if(marketingFundDividend > 0){
            user.marketingFundDividend = user.marketingFundDividend.add(marketingFundDividend);
        }
        if(isRevenueWithdrawable){
            devDividend = user.devDividend;
            userDividend = user.userDividend;
            marketingFundDividend = user.marketingFundDividend;
            if(devDividend > 0){
                safeSHARDTransfer(developerDAOFund, devDividend);
            }
            if(userDividend > 0){
                safeSHARDTransfer(msg.sender, userDividend);
            }
            if(marketingFundDividend > 0){
                safeSHARDTransfer(marketingFund, marketingFundDividend);
            }
            user.devDividend = 0;
            user.userDividend = 0;
            user.marketingFundDividend = 0;
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Safe SHD transfer function, just in case if rounding error causes pool to not have enough SHDs.
    function safeSHARDTransfer(address _to, uint256 _amount) internal {
        uint256 SHARDBal = SHARD.balanceOf(address(this));
        if (_amount > SHARDBal) {
            SHARD.transfer(_to, SHARDBal);
        } else {
            SHARD.transfer(_to, _amount);
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view virtual returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    // View function to see pending SHDs on frontend.
    function pendingSHARD(uint256 _pid, address _user) external view virtual 
    returns (uint256 _pending, uint256 _potential, uint256 _blockNumber) {
        _blockNumber = block.number;
        (_pending, _potential) = calculatePendingSHARD(_pid, _user);
    }

    function pendingSHARDByPids(uint256[] memory _pids, address _user) external view virtual
    returns (uint256[] memory _pending, uint256[] memory _potential, uint256 _blockNumber){
        uint256 poolCount = _pids.length;
        _pending = new uint256[](poolCount);
        _potential = new uint256[](poolCount);
        _blockNumber = block.number;
        for(uint i = 0; i < poolCount; i ++){
            (_pending[i], _potential[i]) = calculatePendingSHARD(_pids[i], _user);
        }
    } 

    function calculatePendingSHARD(uint256 _pid, address _user) private view returns (uint256 _pending, uint256 _potential) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accShardPerWeight = pool.accShardPerWeight;
        _pending = user.modifiedWeight.mul(accShardPerWeight).div(1e12).sub(user.rewardDebt).add(user.revenue);
        bool isContractSender = isUserContractSender[_pid][_user];
        _potential = _pending;
        (,,_pending) = calculateDividend(_pending, _pid, user.amount, isContractSender);
        _pending = _pending.add(user.userDividend);
        uint256 lpSupply = pool.tokenAmount;
        if (block.number > pool.lastDividendHeight && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastDividendHeight, block.number);
            uint256 totalUnupdateToken = multiplier.mul(SHDPerBlock);
            totalUnupdateToken = totalAvailableDividend > totalUnupdateToken? totalUnupdateToken: totalAvailableDividend;
            uint256 shardReward = totalUnupdateToken.mul(pool.allocPoint).div(totalAllocPoint);
            accShardPerWeight = accShardPerWeight.add(shardReward.mul(1e12).div(pool.totalWeight));
        }
        _potential = user.modifiedWeight.mul(accShardPerWeight).div(1e12).sub(user.rewardDebt).add(user.revenue).sub(_potential);
        (,,_potential) = calculateDividend(_potential, _pid, user.amount, isContractSender);
    }

    function getDepositWeight(uint256 _amount) public pure returns(uint256 weight){
        return _amount;
    }

    function getPoolLength() public view virtual returns(uint256){
        return poolInfo.length;
    }

    function getPoolInfo(uint256 _pid) public view virtual returns(uint256 _allocPoint, uint256 _accumulativeDividend, uint256 _usersTotalWeight, uint256 _tokenAmount, address _tokenAddress, uint256 _accs){
        PoolInfo storage pool = poolInfo[_pid];
        _allocPoint = pool.allocPoint;
        _accumulativeDividend = pool.accumulativeDividend;
        _usersTotalWeight = pool.totalWeight;
        _tokenAmount = pool.tokenAmount;
        _tokenAddress = address(pool.token);
        _accs = pool.accShardPerWeight;
    }

    function getPagePoolInfo(uint256 _fromIndex, uint256 _toIndex) public view virtual
    returns(uint256[] memory _allocPoint, uint256[] memory _accumulativeDividend, uint256[] memory _usersTotalWeight, uint256[] memory _tokenAmount, 
    address[] memory _tokenAddress, uint256[] memory _accs){
        uint256 poolCount = _toIndex.sub(_fromIndex).add(1);
        _allocPoint = new uint256[](poolCount);
        _accumulativeDividend = new uint256[](poolCount);
        _usersTotalWeight = new uint256[](poolCount);
        _tokenAmount = new uint256[](poolCount);
        _tokenAddress = new address[](poolCount);
        _accs = new uint256[](poolCount);
        uint256 startIndex = 0;
        for(uint i = _fromIndex; i <= _toIndex; i ++){
            PoolInfo storage pool = poolInfo[i];
            _allocPoint[startIndex] = pool.allocPoint;
            _accumulativeDividend[startIndex] = pool.accumulativeDividend;
            _usersTotalWeight[startIndex] = pool.totalWeight;
            _tokenAmount[startIndex] = pool.tokenAmount;
            _tokenAddress[startIndex] = address(pool.token);
            _accs[startIndex] = pool.accShardPerWeight;
            startIndex ++;
        }
    }

    function getUserInfoByPids(uint256[] memory _pids, address _user) public virtual view 
    returns(uint256[] memory _amount, uint256[] memory _modifiedWeight, uint256[] memory _revenue, uint256[] memory _userDividend, uint256[] memory _rewardDebt) {
        uint256 poolCount = _pids.length;
        _amount = new uint256[](poolCount);
        _modifiedWeight = new uint256[](poolCount);
        _revenue = new uint256[](poolCount);
        _userDividend = new uint256[](poolCount);
        _rewardDebt = new uint256[](poolCount);
        for(uint i = 0; i < poolCount; i ++){
            UserInfo storage user = userInfo[_pids[i]][_user];
            _amount[i] = user.amount;
            _modifiedWeight[i] = user.modifiedWeight;
            _revenue[i] = user.revenue;
            _userDividend[i] = user.userDividend;
            _rewardDebt[i] = user.rewardDebt;
        }
    }

    function updateUserRevenue(UserInfo storage _user, PoolInfo storage _pool) private returns (uint256){
        uint256 pending = _user.modifiedWeight.mul(_pool.accShardPerWeight).div(1e12).sub(_user.rewardDebt);
        _user.revenue = _user.revenue.add(pending);
        _pool.accumulativeDividend = _pool.accumulativeDividend.sub(pending);
        return _user.revenue;
    }

    function updateInvitorWeight(address _sender, address _invitor, uint256 _pid, bool _isAddAmount, uint256 _amount, bool _isWithdrawn, bool _withdrawnState) private {
        UserInfo storage user = userInfo[_pid][_sender];
        uint256 subInviteeAmount = 0;
        uint256 addInviteeAmount = 0;
        if(user.amount > 0  && !_withdrawnState){
            subInviteeAmount = user.originWeight;
        }
        if(!_isWithdrawn){
            if(_isAddAmount){
                addInviteeAmount = getDepositWeight(user.amount.add(_amount));
            }
            else{ 
                addInviteeAmount = getDepositWeight(user.amount.sub(_amount));
            }
        }

        UserInfo storage invitor = userInfo[_pid][_invitor];
        PoolInfo storage pool = poolInfo[_pid];
        uint256 inviteeAmountOfUserInvitor = userInviteeTotalAmount[_pid][_invitor];
        uint256 newInviteeAmountOfUserInvitor = inviteeAmountOfUserInvitor.add(addInviteeAmount).sub(subInviteeAmount);
        userInviteeTotalAmount[_pid][_invitor] = newInviteeAmountOfUserInvitor;
        if(invitor.amount > 0){
            invitor.modifiedWeight = invitor.modifiedWeight.add(newInviteeAmountOfUserInvitor.div(INVITEE_WEIGHT))
                                                                   .sub(inviteeAmountOfUserInvitor.div(INVITEE_WEIGHT));
            pool.totalWeight = pool.totalWeight.add(newInviteeAmountOfUserInvitor.div(INVITEE_WEIGHT))
                                               .sub(inviteeAmountOfUserInvitor.div(INVITEE_WEIGHT));                              
        }
    }

    function updateUserWeight(address _user, uint256 _pid, bool _isAddAmount, uint256 _amount, bool _isWithdrawn) private {
        UserInfo storage user = userInfo[_pid][_user];
        uint256 userOriginModifiedWeight = user.modifiedWeight;
        uint256 userNewModifiedWeight;
        if(_isAddAmount){
            userNewModifiedWeight = getDepositWeight(_amount.add(user.amount));
        }
        else{
            userNewModifiedWeight = getDepositWeight(user.amount.sub(_amount));
        }
        user.originWeight = userNewModifiedWeight;
        if(!_isWithdrawn){
            userNewModifiedWeight = userNewModifiedWeight.add(userNewModifiedWeight.div(INVITOR_WEIGHT));
        }
        uint256 inviteeAmountOfUser = userInviteeTotalAmount[_pid][msg.sender];
        userNewModifiedWeight = userNewModifiedWeight.add(inviteeAmountOfUser.div(INVITEE_WEIGHT));
        user.modifiedWeight = userNewModifiedWeight;
        PoolInfo storage pool = poolInfo[_pid];
        pool.totalWeight = pool.totalWeight.add(userNewModifiedWeight).sub(userOriginModifiedWeight);
    }

    function updateAfterModifyStartBlock(uint256 _newStartBlock) internal override{
        uint256 poolLenght = poolInfo.length;
        for(uint256 i = 0; i < poolLenght; i++){
            PoolInfo storage info = poolInfo[i];
            info.lastDividendHeight = _newStartBlock;
        }
    }
}