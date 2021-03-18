// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import '@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol';
import "../interfaces/IInvitation.sol";
import "./ActivityBase.sol";
import "./SHDToken.sol";

contract ShardingDAOMining is IInvitation, ActivityBase {
    using SafeMath for uint256;
    using SafeERC20 for IERC20; 
    using FixedPoint for *;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How much LP token the user has provided.
        uint256 originWeight; //initial weight
        uint256 inviteeWeight; // invitees' weight
        uint256 endBlock;
        bool isCalculateInvitation;
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 nftPoolId;
        address lpTokenSwap; // uniswapPair contract address
        uint256 accumulativeDividend;
        uint256 usersTotalWeight; // user's sum weight
        uint256 lpTokenAmount; // lock amount
        uint256 oracleWeight; // eth value
        uint256 lastDividendHeight; // last dividend block height
        TokenPairInfo tokenToEthPairInfo;
        bool isFirstTokenShard;
    }

    struct TokenPairInfo{
        IUniswapV2Pair tokenToEthSwap; 
        FixedPoint.uq112x112 price; 
        bool isFirstTokenEth;
        uint256 priceCumulativeLast;
        uint32  blockTimestampLast;
        uint256 lastPriceUpdateHeight;
    }

    struct InvitationInfo {
        address invitor;
        address[] invitees;
        bool isUsed;
        bool isWithdrawn;
        mapping(address => uint256) inviteeIndexMap;
    }

    // black list
    struct EvilPoolInfo {
        uint256 pid;
        string description;
    }

    // The SHD TOKEN!
    SHDToken public SHD;
    // Info of each pool.
    uint256[] public rankPoolIndex;
    // indicates whether the pool is in the rank
    mapping(uint256 => uint256) public rankPoolIndexMap;
    // relationship info about invitation
    mapping(address => InvitationInfo) public usersRelationshipInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Info of each pool.
    PoolInfo[] private poolInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public maxRankNumber = 10;
    // Last block number that SHARDs distribution occurs.
    uint256 public lastRewardBlock;
    // produced blocks per day
    uint256 public constant produceBlocksPerDay = 6496;
    // produced blocks per month
    uint256 public constant produceBlocksPerMonth = produceBlocksPerDay * 30;
    // SHD tokens created per block.
    uint256 public SHDPerBlock = 11052 * (1e14);
    // after each term, mine half SHD token
    uint256 public constant MINT_DECREASE_TERM = 9500000;
    // used to caculate user deposit weight
    uint256[] private depositTimeWeight;
    // max lock time in stage two
    uint256 private constant MAX_MONTH = 36;
    // add pool automatically in nft shard
    address public nftShard;
    // oracle token price update term
    uint256 public updateTokenPriceTerm = 120;
    // to mint token cross chain
    uint256 public shardMintWeight = 1;
    uint256 public reserveMintWeight = 0;
    uint256 public reserveToMint;
    // black list
    EvilPoolInfo[] public blackList;
    mapping(uint256 => uint256) public blackListMap;
    // undividend shard
    uint256 public unDividendShard;
    // 20% shard => SHD - ETH pool
    uint256 public shardPoolDividendWeight = 2;
    // 80% shard => SHD - ETH pool
    uint256 public otherPoolDividendWeight = 8;

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        uint256 weight
    );
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Replace(
        address indexed user,
        uint256 indexed rankIndex,
        uint256 newPid
    );

    event AddToBlacklist(
        uint256 indexed pid
    );

    event RemoveFromBlacklist(
        uint256 indexed pid
    );
    event AddPool(uint256 indexed pid, uint256 nftId, address tokenAddress);

    function initialize(
        SHDToken _SHD,
        address _wethToken,
        address _developerDAOFund,
        address _marketingFund,
        uint256 _maxRankNumber,
        uint256 _startBlock
    ) public virtual onlyOwner{
        require(WETHToken == address(0), "already initialized");
        SHD = _SHD;
        maxRankNumber = _maxRankNumber;
        if (_startBlock < block.number) {
            startBlock = block.number;
        } else {
            startBlock = _startBlock;
        }
        lastRewardBlock = startBlock.sub(1);
        WETHToken = _wethToken;
        initializeTimeWeight();
        developerDAOFund = _developerDAOFund;
        marketingFund = _marketingFund;
        InvitationInfo storage initialInvitor =
            usersRelationshipInfo[address(this)];

        userDividendWeight = 8;
        devDividendWeight = 2;

        amountFeeRateNumerator = 0;
        amountfeeRateDenominator = 0;

        contractFeeRateNumerator = 1;
        contractFeeRateDenominator = 5;
        initialInvitor.isUsed = true;
    }

    function initializeTimeWeight() private {
        depositTimeWeight = [
            1238,
            1383,
            1495,
            1587,
            1665,
            1732,
            1790,
            1842,
            1888,
            1929,
            1966,
            2000,
            2031,
            2059,
            2085,
            2108,
            2131,
            2152,
            2171,
            2189,
            2206,
            2221,
            2236,
            2250,
            2263,
            2276,
            2287,
            2298,
            2309,
            2319,
            2328,
            2337,
            2346,
            2355,
            2363,
            2370
        ];
    }

    function setNftShard(address _nftShard) public virtual {
        checkAdmin();
        nftShard = _nftShard;
    }

    // Add a new lp to the pool. Can only be called by the nft shard contract.
    // if _lpTokenSwap contains tokenA instead of eth, then _tokenToEthSwap should consist of token A and eth
    function add(
        uint256 _nftPoolId,
        IUniswapV2Pair _lpTokenSwap,
        IUniswapV2Pair _tokenToEthSwap
    ) public virtual {
        require(msg.sender == nftShard || msg.sender == admin, "invalid sender");
        TokenPairInfo memory tokenToEthInfo;
        uint256 lastDividendHeight = 0;
        if(poolInfo.length == 0){
            _nftPoolId = 0;
            lastDividendHeight = lastRewardBlock;
        }
        bool isFirstTokenShard;
        if (address(_tokenToEthSwap) != address(0)) {
            (address token0, address token1, uint256 targetTokenPosition) =
                getTargetTokenInSwap(_tokenToEthSwap, WETHToken);
            address wantToken;
            bool isFirstTokenEthToken;
            if (targetTokenPosition == 0) {
                isFirstTokenEthToken = true;
                wantToken = token1;
            } else {
                isFirstTokenEthToken = false;
                wantToken = token0;
            }
            (, , targetTokenPosition) = getTargetTokenInSwap(
                _lpTokenSwap,
                wantToken
            );
            if (targetTokenPosition == 0) {
                isFirstTokenShard = false;
            } else {
                isFirstTokenShard = true;
            }
            tokenToEthInfo = generateOrcaleInfo(
                _tokenToEthSwap,
                isFirstTokenEthToken
            );
        } else {
            (, , uint256 targetTokenPosition) =
                getTargetTokenInSwap(_lpTokenSwap, WETHToken);
            if (targetTokenPosition == 0) {
                isFirstTokenShard = false;
            } else {
                isFirstTokenShard = true;
            }
            tokenToEthInfo = generateOrcaleInfo(
                _lpTokenSwap,
                !isFirstTokenShard
            );
        }
        poolInfo.push(
            PoolInfo({
                nftPoolId: _nftPoolId,
                lpTokenSwap: address(_lpTokenSwap),
                lpTokenAmount: 0,
                usersTotalWeight: 0,
                accumulativeDividend: 0,
                oracleWeight: 0,
                lastDividendHeight: lastDividendHeight,
                tokenToEthPairInfo: tokenToEthInfo,
                isFirstTokenShard: isFirstTokenShard
            })
        );
        emit AddPool(poolInfo.length.sub(1), _nftPoolId, address(_lpTokenSwap));
    }

    function setPriceUpdateTerm(uint256 _term) public virtual onlyOwner{
        updateTokenPriceTerm = _term;
    }

    function kickEvilPoolByPid(uint256 _pid, string calldata description)
        public
        virtual
        onlyOwner
    {
        bool isDescriptionLeagal = verifyDescription(description);
        require(isDescriptionLeagal, "invalid description, just ASCII code is allowed");
        require(_pid > 0, "invalid pid");
        uint256 poolRankIndex = rankPoolIndexMap[_pid];
        if (poolRankIndex > 0) {
            massUpdatePools();
            uint256 _rankIndex = poolRankIndex.sub(1);
            uint256 currentRankLastIndex = rankPoolIndex.length.sub(1);
            uint256 lastPidInRank = rankPoolIndex[currentRankLastIndex];
            rankPoolIndex[_rankIndex] = lastPidInRank;
            rankPoolIndexMap[lastPidInRank] = poolRankIndex;
            delete rankPoolIndexMap[_pid];
            rankPoolIndex.pop();
        }
        addInBlackList(_pid, description);
        dealEvilPoolDiviend(_pid);
        emit AddToBlacklist(_pid);
    }

    function addInBlackList(uint256 _pid, string calldata description) private {
        if (blackListMap[_pid] > 0) {
            return;
        }
        blackList.push(EvilPoolInfo({pid: _pid, description: description}));
        blackListMap[_pid] = blackList.length;
    }

    function resetEvilPool(uint256 _pid) public virtual onlyOwner {
        uint256 poolPosition = blackListMap[_pid];
        if (poolPosition == 0) {
            return;
        }
        uint256 poolIndex = poolPosition.sub(1);
        uint256 lastIndex = blackList.length.sub(1);
        EvilPoolInfo storage lastEvilInBlackList = blackList[lastIndex];
        uint256 lastPidInBlackList = lastEvilInBlackList.pid;
        blackListMap[lastPidInBlackList] = poolPosition;
        blackList[poolIndex] = blackList[lastIndex];
        delete blackListMap[_pid];
        blackList.pop();
        emit RemoveFromBlacklist(_pid);
    }

    function dealEvilPoolDiviend(uint256 _pid) private {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 undistributeDividend = pool.accumulativeDividend;
        if (undistributeDividend == 0) {
            return;
        }
        uint256 currentRankCount = rankPoolIndex.length;
        if (currentRankCount > 0) {
            uint256 averageDividend =
                undistributeDividend.div(currentRankCount);
            for (uint256 i = 0; i < currentRankCount; i++) {
                PoolInfo storage poolInRank = poolInfo[rankPoolIndex[i]];
                if (i < currentRankCount - 1) {
                    poolInRank.accumulativeDividend = poolInRank
                        .accumulativeDividend
                        .add(averageDividend);
                    undistributeDividend = undistributeDividend.sub(
                        averageDividend
                    );
                } else {
                    poolInRank.accumulativeDividend = poolInRank
                        .accumulativeDividend
                        .add(undistributeDividend);
                }
            }
        } else {
            unDividendShard = unDividendShard.add(undistributeDividend);
        }
        pool.accumulativeDividend = 0;
    }

    function setMintCoefficient(
        uint256 _shardMintWeight,
        uint256 _reserveMintWeight
    ) public virtual {
        checkAdmin();
        require(
            _shardMintWeight != 0 && _reserveMintWeight != 0,
            "invalid input"
        );
        massUpdatePools();
        shardMintWeight = _shardMintWeight;
        reserveMintWeight = _reserveMintWeight;
    }

    function setShardPoolDividendWeight(
        uint256 _shardPoolWeight,
        uint256 _otherPoolWeight
    ) public virtual {
        checkAdmin();
        require(
            _shardPoolWeight != 0 && _otherPoolWeight != 0,
            "invalid input"
        );
        massUpdatePools();
        shardPoolDividendWeight = _shardPoolWeight;
        otherPoolDividendWeight = _otherPoolWeight;
    }

    function setSHDPerBlock(uint256 _SHDPerBlock, bool _withUpdate) public virtual {
        checkAdmin();
        if (_withUpdate) {
            massUpdatePools();
        }
        SHDPerBlock = _SHDPerBlock;
    }

    function massUpdatePools() public virtual {
        uint256 poolCountInRank = rankPoolIndex.length;
        uint256 farmMintShard = mintSHARD(address(this), block.number);
        updateSHARDPoolAccumulativeDividend(block.number);
        if(poolCountInRank == 0){
            farmMintShard = farmMintShard.mul(otherPoolDividendWeight)
                                     .div(shardPoolDividendWeight.add(otherPoolDividendWeight));
            if(farmMintShard > 0){
                unDividendShard = unDividendShard.add(farmMintShard);
            }
        }
        for (uint256 i = 0; i < poolCountInRank; i++) {
            updatePoolAccumulativeDividend(
                rankPoolIndex[i],
                poolCountInRank,
                block.number
            );
        }
    }

    // update reward vairables for a pool
    function updatePoolDividend(uint256 _pid) public virtual {
        if(_pid == 0){
            updateSHARDPoolAccumulativeDividend(block.number);
            return;
        }
        if (rankPoolIndexMap[_pid] == 0) {
            return;
        }
        updatePoolAccumulativeDividend(
            _pid,
            rankPoolIndex.length,
            block.number
        );
    }

    function mintSHARD(address _address, uint256 _toBlock) private returns (uint256){
        uint256 recentlyRewardBlock = lastRewardBlock;
        if (recentlyRewardBlock >= _toBlock) {
            return 0;
        }
        uint256 totalReward =
            getRewardToken(recentlyRewardBlock.add(1), _toBlock);
        uint256 farmMint =
            totalReward.mul(shardMintWeight).div(
                reserveMintWeight.add(shardMintWeight)
            );
        uint256 reserve = totalReward.sub(farmMint);
        if (totalReward > 0) {
            SHD.mint(_address, farmMint);
            if (reserve > 0) {
                reserveToMint = reserveToMint.add(reserve);
            }
            lastRewardBlock = _toBlock;
        }
        return farmMint;
    }

    function updatePoolAccumulativeDividend(
        uint256 _pid,
        uint256 _validRankPoolCount,
        uint256 _toBlock
    ) private {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.lastDividendHeight >= _toBlock) return;
        uint256 poolReward =
            getModifiedRewardToken(pool.lastDividendHeight.add(1), _toBlock)
                                    .mul(otherPoolDividendWeight)
                                    .div(shardPoolDividendWeight.add(otherPoolDividendWeight));

        uint256 otherPoolReward = poolReward.div(_validRankPoolCount);                            
        pool.lastDividendHeight = _toBlock;
        uint256 existedDividend = pool.accumulativeDividend;
        pool.accumulativeDividend = existedDividend.add(otherPoolReward);
    }

    function updateSHARDPoolAccumulativeDividend (uint256 _toBlock) private{
        PoolInfo storage pool = poolInfo[0];
        if (pool.lastDividendHeight >= _toBlock) return;
        uint256 poolReward =
            getModifiedRewardToken(pool.lastDividendHeight.add(1), _toBlock);

        uint256 shardPoolDividend = poolReward.mul(shardPoolDividendWeight)
                                               .div(shardPoolDividendWeight.add(otherPoolDividendWeight));                              
        pool.lastDividendHeight = _toBlock;
        uint256 existedDividend = pool.accumulativeDividend;
        pool.accumulativeDividend = existedDividend.add(shardPoolDividend);
    }

    // deposit LP tokens to MasterChef for SHD allocation.
    // ignore lockTime in stage one
    function deposit(
        uint256 _pid,
        uint256 _amount,
        uint256 _lockTime
    ) public virtual {
        require(_amount > 0, "invalid deposit amount");
        InvitationInfo storage senderInfo = usersRelationshipInfo[msg.sender];
        require(senderInfo.isUsed, "must accept an invitation firstly");
        require(_lockTime > 0 && _lockTime <= 36, "invalid lock time"); // less than 36 months
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpTokenAmount = pool.lpTokenAmount.add(_amount);
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 newOriginWeight = user.originWeight;
        uint256 existedAmount = user.amount;
        uint256 endBlock = user.endBlock;
        uint256 newEndBlock =
            block.number.add(produceBlocksPerMonth.mul(_lockTime));
        if (existedAmount > 0) {
            if (block.number >= endBlock) {
                newOriginWeight = getDepositWeight(
                    _amount.add(existedAmount),
                    _lockTime
                );
            } else {
                newOriginWeight = newOriginWeight.add(getDepositWeight(_amount, _lockTime));
                newOriginWeight = newOriginWeight.add(
                    getDepositWeight(
                        existedAmount,
                        newEndBlock.sub(endBlock).div(produceBlocksPerMonth)
                    )
                );
            }
        } else {
            judgeContractSender(_pid);
            newOriginWeight = getDepositWeight(_amount, _lockTime);
        }
        modifyWeightByInvitation(
            _pid,
            msg.sender,
            user.originWeight,
            newOriginWeight,
            user.inviteeWeight,
            existedAmount
        );   
        updateUserInfo(
            user,
            existedAmount.add(_amount),
            newOriginWeight,
            newEndBlock
        );
        IERC20(pool.lpTokenSwap).safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        pool.oracleWeight =  getOracleWeight(pool, lpTokenAmount);
        pool.lpTokenAmount = lpTokenAmount;
        if (
            rankPoolIndexMap[_pid] == 0 &&
            rankPoolIndex.length < maxRankNumber &&
            blackListMap[_pid] == 0
        ) {
            addToRank(pool, _pid);
        }
        emit Deposit(msg.sender, _pid, _amount, newOriginWeight);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid) public virtual {
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        require(amount > 0, "user is not existed");
        require(user.endBlock < block.number, "token is still locked");
        mintSHARD(address(this), block.number);
        updatePoolDividend(_pid);
        uint256 originWeight = user.originWeight;
        PoolInfo storage pool = poolInfo[_pid];
        uint256 usersTotalWeight = pool.usersTotalWeight;
        uint256 userWeight = user.inviteeWeight.add(originWeight);
        if(user.isCalculateInvitation){
            userWeight = userWeight.add(originWeight.div(INVITOR_WEIGHT));
        }
        if (pool.accumulativeDividend > 0) {
            uint256 pending = pool.accumulativeDividend.mul(userWeight).div(usersTotalWeight);
            pool.accumulativeDividend = pool.accumulativeDividend.sub(pending);
            uint256 treasruyDividend;
            uint256 devDividend;
            (treasruyDividend, devDividend, pending) = calculateDividend(pending, _pid, amount, isUserContractSender[_pid][msg.sender]);
            if(treasruyDividend > 0){
                safeSHARDTransfer(marketingFund, treasruyDividend);
            }
            if(devDividend > 0){
                safeSHARDTransfer(developerDAOFund, devDividend);
            }
            if(pending > 0){
                safeSHARDTransfer(msg.sender, pending);
            }
        }
        pool.usersTotalWeight = usersTotalWeight.sub(userWeight);
        user.amount = 0;
        user.originWeight = 0;
        user.endBlock = 0;
        IERC20(pool.lpTokenSwap).safeTransfer(address(msg.sender), amount);
        pool.lpTokenAmount = pool.lpTokenAmount.sub(amount);
        if (pool.lpTokenAmount == 0) pool.oracleWeight = 0;
        else {
            pool.oracleWeight = getOracleWeight(pool, pool.lpTokenAmount);
        }
        resetInvitationRelationship(_pid, msg.sender, originWeight);
        emit Withdraw(msg.sender, _pid, amount);
    }

    function addToRank(
        PoolInfo storage _pool,
        uint256 _pid
    ) private {
        if(_pid == 0){
            return;
        }
        massUpdatePools();
        _pool.lastDividendHeight = block.number;
        rankPoolIndex.push(_pid);
        rankPoolIndexMap[_pid] = rankPoolIndex.length;
        if(unDividendShard > 0){
            _pool.accumulativeDividend = _pool.accumulativeDividend.add(unDividendShard);
            unDividendShard = 0;
        }
        emit Replace(msg.sender, rankPoolIndex.length.sub(1), _pid);
        return;
    }

    //_poolIndexInRank is the index in rank
    //_pid is the index in poolInfo
    function tryToReplacePoolInRank(uint256 _poolIndexInRank, uint256 _pid)
        public
        virtual
    {
        if(_pid == 0){
            return;
        }
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.lpTokenAmount > 0, "there is not any lp token depsoited");
        require(blackListMap[_pid] == 0, "pool is in the black list");
        if (rankPoolIndexMap[_pid] > 0) {
            return;
        }
        uint256 currentPoolCountInRank = rankPoolIndex.length;
        require(currentPoolCountInRank == maxRankNumber, "invalid operation");
        uint256 targetPid = rankPoolIndex[_poolIndexInRank];
        PoolInfo storage targetPool = poolInfo[targetPid];
        uint256 targetPoolOracleWeight = getOracleWeight(targetPool, targetPool.lpTokenAmount);
        uint256 challengerOracleWeight = getOracleWeight(pool, pool.lpTokenAmount);
        if (challengerOracleWeight <= targetPoolOracleWeight) {
            return;
        }
        updatePoolDividend(targetPid);
        rankPoolIndex[_poolIndexInRank] = _pid;
        delete rankPoolIndexMap[targetPid];
        rankPoolIndexMap[_pid] = _poolIndexInRank.add(1);
        pool.lastDividendHeight = block.number;
        emit Replace(msg.sender, _poolIndexInRank, _pid);
    }

    function acceptInvitation(address _invitor) public virtual override {
        require(_invitor != msg.sender, "invitee should not be invitor");
        buildInvitation(_invitor, msg.sender);
    }

    function buildInvitation(address _invitor, address _invitee) private {
        InvitationInfo storage invitee = usersRelationshipInfo[_invitee];
        require(!invitee.isUsed, "has accepted invitation");
        invitee.isUsed = true;
        InvitationInfo storage invitor = usersRelationshipInfo[_invitor];
        require(invitor.isUsed, "invitor has not acceptted invitation");
        invitee.invitor = _invitor;
        invitor.invitees.push(_invitee);
        invitor.inviteeIndexMap[_invitee] = invitor.invitees.length.sub(1);
    }

    function setMaxRankNumber(uint256 _count) public virtual {
        checkAdmin();
        require(_count > 0, "invalid count");
        if (maxRankNumber == _count) return;
        massUpdatePools();
        maxRankNumber = _count;
        uint256 currentPoolCountInRank = rankPoolIndex.length;
        if (_count >= currentPoolCountInRank) {
            return;
        }
        uint256 sparePoolCount = currentPoolCountInRank.sub(_count);
        uint256 lastPoolIndex = currentPoolCountInRank.sub(1);
        while (sparePoolCount > 0) {
            delete rankPoolIndexMap[rankPoolIndex[lastPoolIndex]];
            rankPoolIndex.pop();
            lastPoolIndex--;
            sparePoolCount--;
        }
    }

    function getModifiedRewardToken(uint256 _fromBlock, uint256 _toBlock)
        private
        view
        returns (uint256)
    {
        return
            getRewardToken(_fromBlock, _toBlock).mul(shardMintWeight).div(
                reserveMintWeight.add(shardMintWeight)
            );
    }

    // View function to see pending SHARDs on frontend.
    function pendingSHARD(uint256 _pid, address _user)
        external
        view
        virtual
        returns (uint256 _pending, uint256 _potential, uint256 _blockNumber)
    {
        _blockNumber = block.number;
        (_pending, _potential) = calculatePendingSHARD(_pid, _user);
        
    }

    function pendingSHARDByPids(uint256[] memory _pids, address _user)
        external
        view
        virtual
        returns (uint256[] memory _pending, uint256[] memory _potential, uint256 _blockNumber)
    {
         uint256 poolCount = _pids.length;
        _pending = new uint256[](poolCount);
        _potential = new uint256[](poolCount);
        _blockNumber = block.number;
        for(uint i = 0; i < poolCount; i ++){
            (_pending[i], _potential[i]) = calculatePendingSHARD(_pids[i], _user);
        }
    }

    function calculatePendingSHARD(uint256 _pid, address _user) private view returns (uint256 _pending, uint256 _potential){
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        if (user.amount == 0) {
            return (0, 0);
        }
        uint256 userModifiedWeight = getUserModifiedWeight(_pid, _user);
        _pending = pool.accumulativeDividend.mul(userModifiedWeight);
        _pending = _pending.div(pool.usersTotalWeight);
        bool isContractSender = isUserContractSender[_pid][_user];
        (,,_pending) = calculateDividend(_pending, _pid, user.amount, isContractSender);
        if (pool.lastDividendHeight >= block.number) {
            return (_pending, 0);
        }
        if (_pid != 0 && (rankPoolIndex.length == 0 || rankPoolIndexMap[_pid] == 0)) {
            return (_pending, 0);
        }
        uint256 poolReward = getModifiedRewardToken(pool.lastDividendHeight.add(1), block.number);
        uint256 numerator;
        uint256 denominator = otherPoolDividendWeight.add(shardPoolDividendWeight);
        if(_pid == 0){
            numerator = shardPoolDividendWeight;
        }
        else{
            numerator = otherPoolDividendWeight;
        }
        poolReward = poolReward       
            .mul(numerator)
            .div(denominator);
        if(_pid != 0){
            poolReward = poolReward.div(rankPoolIndex.length);
        }                          
        _potential = poolReward
            .mul(userModifiedWeight)
            .div(pool.usersTotalWeight);
        (,,_potential) = calculateDividend(_potential, _pid, user.amount, isContractSender);
    }

    //calculate the weight and end block when users deposit
    function getDepositWeight(uint256 _lockAmount, uint256 _lockTime)
        private
        view
        returns (uint256)
    {
        if (_lockTime == 0) return 0;
        if (_lockTime.div(MAX_MONTH) > 1) _lockTime = MAX_MONTH;
        return depositTimeWeight[_lockTime.sub(1)].sub(500).mul(_lockAmount);
    }

    function getPoolLength() public view virtual returns (uint256) {
        return poolInfo.length;
    }

    function getPagePoolInfo(uint256 _fromIndex, uint256 _toIndex)
        public
        view
        virtual
        returns (
            uint256[] memory _nftPoolId,
            uint256[] memory _accumulativeDividend,
            uint256[] memory _usersTotalWeight,
            uint256[] memory _lpTokenAmount,
            uint256[] memory _oracleWeight,
            address[] memory _swapAddress
        )
    {
        uint256 poolCount = _toIndex.sub(_fromIndex).add(1);
        _nftPoolId = new uint256[](poolCount);
        _accumulativeDividend = new uint256[](poolCount);
        _usersTotalWeight = new uint256[](poolCount);
        _lpTokenAmount = new uint256[](poolCount);
        _oracleWeight = new uint256[](poolCount);
        _swapAddress = new address[](poolCount);
        uint256 startIndex = 0;
        for (uint256 i = _fromIndex; i <= _toIndex; i++) {
            PoolInfo storage pool = poolInfo[i];
            _nftPoolId[startIndex] = pool.nftPoolId;
            _accumulativeDividend[startIndex] = pool.accumulativeDividend;
            _usersTotalWeight[startIndex] = pool.usersTotalWeight;
            _lpTokenAmount[startIndex] = pool.lpTokenAmount;
            _oracleWeight[startIndex] = pool.oracleWeight;
            _swapAddress[startIndex] = pool.lpTokenSwap;
            startIndex++;
        }
    }

    function getInstantPagePoolInfo(uint256 _fromIndex, uint256 _toIndex)
    public
    virtual
    returns (
        uint256[] memory _nftPoolId,
        uint256[] memory _accumulativeDividend,
        uint256[] memory _usersTotalWeight,
        uint256[] memory _lpTokenAmount,
        uint256[] memory _oracleWeight,
        address[] memory _swapAddress
    )
    {
        uint256 poolCount = _toIndex.sub(_fromIndex).add(1);
        _nftPoolId = new uint256[](poolCount);
        _accumulativeDividend = new uint256[](poolCount);
        _usersTotalWeight = new uint256[](poolCount);
        _lpTokenAmount = new uint256[](poolCount);
        _oracleWeight = new uint256[](poolCount);
        _swapAddress = new address[](poolCount);
        uint256 startIndex = 0;
        for (uint256 i = _fromIndex; i <= _toIndex; i++) {
            PoolInfo storage pool = poolInfo[i];
            _nftPoolId[startIndex] = pool.nftPoolId;
            _accumulativeDividend[startIndex] = pool.accumulativeDividend;
            _usersTotalWeight[startIndex] = pool.usersTotalWeight;
            _lpTokenAmount[startIndex] = pool.lpTokenAmount;
            _oracleWeight[startIndex] = getOracleWeight(pool, _lpTokenAmount[startIndex]);
            _swapAddress[startIndex] = pool.lpTokenSwap;
            startIndex++;
        }
    }

    function getRankList() public view virtual returns (uint256[] memory) {
        uint256[] memory rankIdList = rankPoolIndex;
        return rankIdList;
    }

    function getBlackList()
        public
        view
        virtual
        returns (EvilPoolInfo[] memory _blackList)
    {
        _blackList = blackList;
    }

    function getInvitation(address _sender)
        public
        view
        virtual
        override
        returns (
            address _invitor,
            address[] memory _invitees,
            bool _isWithdrawn
        )
    {
        InvitationInfo storage invitation = usersRelationshipInfo[_sender];
        _invitees = invitation.invitees;
        _invitor = invitation.invitor;
        _isWithdrawn = invitation.isWithdrawn;
    }

    function getUserInfo(uint256 _pid, address _user)
        public
        view
        virtual
        returns (
            uint256 _amount,
            uint256 _originWeight,
            uint256 _modifiedWeight,
            uint256 _endBlock
        )
    {
        UserInfo storage user = userInfo[_pid][_user];
        _amount = user.amount;
        _originWeight = user.originWeight;
        _modifiedWeight = getUserModifiedWeight(_pid, _user);
        _endBlock = user.endBlock;
    }

    function getUserInfoByPids(uint256[] memory _pids, address _user)
        public
        view
        virtual
        returns (
            uint256[] memory _amount,
            uint256[] memory _originWeight,
            uint256[] memory _modifiedWeight,
            uint256[] memory _endBlock
        )
    {
        uint256 poolCount = _pids.length;
        _amount = new uint256[](poolCount);
        _originWeight = new uint256[](poolCount);
        _modifiedWeight = new uint256[](poolCount);
        _endBlock = new uint256[](poolCount);
        for(uint i = 0; i < poolCount; i ++){
            (_amount[i], _originWeight[i], _modifiedWeight[i], _endBlock[i]) = getUserInfo(_pids[i], _user);
        }
    }

    function getOracleInfo(uint256 _pid)
        public
        view
        virtual
        returns (
            address _swapToEthAddress,
            uint256 _priceCumulativeLast,
            uint256 _blockTimestampLast,
            uint256 _price,
            uint256 _lastPriceUpdateHeight
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        _swapToEthAddress = address(pool.tokenToEthPairInfo.tokenToEthSwap);
        _priceCumulativeLast = pool.tokenToEthPairInfo.priceCumulativeLast;
        _blockTimestampLast = pool.tokenToEthPairInfo.blockTimestampLast;
        _price = pool.tokenToEthPairInfo.price._x;
        _lastPriceUpdateHeight = pool.tokenToEthPairInfo.lastPriceUpdateHeight;
    }

    // Safe SHD transfer function, just in case if rounding error causes pool to not have enough SHARDs.
    function safeSHARDTransfer(address _to, uint256 _amount) internal {
        uint256 SHARDBal = SHD.balanceOf(address(this));
        if (_amount > SHARDBal) {
            SHD.transfer(_to, SHARDBal);
        } else {
            SHD.transfer(_to, _amount);
        }
    }

    function updateUserInfo(
        UserInfo storage _user,
        uint256 _amount,
        uint256 _originWeight,
        uint256 _endBlock
    ) private {
        _user.amount = _amount;
        _user.originWeight = _originWeight;
        _user.endBlock = _endBlock;
    }

    function getOracleWeight(
        PoolInfo storage _pool,
        uint256 _amount
    ) private returns (uint256 _oracleWeight) {
        _oracleWeight = calculateOracleWeight(_pool, _amount);
        _pool.oracleWeight = _oracleWeight;
    }

    function calculateOracleWeight(PoolInfo storage _pool, uint256 _amount)
        private
        returns (uint256 _oracleWeight)
    {
        uint256 lpTokenTotalSupply =
            IUniswapV2Pair(_pool.lpTokenSwap).totalSupply();
        (uint112 shardReserve, uint112 wantTokenReserve, ) =
            IUniswapV2Pair(_pool.lpTokenSwap).getReserves();
        if (_amount == 0) {
            _amount = _pool.lpTokenAmount;
            if (_amount == 0) {
                return 0;
            }
        }
        if (!_pool.isFirstTokenShard) {
            uint112 wantToken = wantTokenReserve;
            wantTokenReserve = shardReserve;
            shardReserve = wantToken;
        }
        FixedPoint.uq112x112 memory price =
            updateTokenOracle(_pool.tokenToEthPairInfo);
        if (
            address(_pool.tokenToEthPairInfo.tokenToEthSwap) ==
            _pool.lpTokenSwap
        ) {
            _oracleWeight = uint256(price.mul(shardReserve).decode144())
                .mul(2)
                .mul(_amount)
                .div(lpTokenTotalSupply);
        } else {
            _oracleWeight = uint256(price.mul(wantTokenReserve).decode144())
                .mul(2)
                .mul(_amount)
                .div(lpTokenTotalSupply);
        }
    }

    function resetInvitationRelationship(
        uint256 _pid,
        address _user,
        uint256 _originWeight
    ) private {
        InvitationInfo storage senderRelationshipInfo =
            usersRelationshipInfo[_user];
        if (!senderRelationshipInfo.isWithdrawn){
            senderRelationshipInfo.isWithdrawn = true;
            InvitationInfo storage invitorRelationshipInfo =
            usersRelationshipInfo[senderRelationshipInfo.invitor];
            uint256 targetIndex = invitorRelationshipInfo.inviteeIndexMap[_user];
            uint256 inviteesCount = invitorRelationshipInfo.invitees.length;
            address lastInvitee =
            invitorRelationshipInfo.invitees[inviteesCount.sub(1)];
            invitorRelationshipInfo.inviteeIndexMap[lastInvitee] = targetIndex;
            invitorRelationshipInfo.invitees[targetIndex] = lastInvitee;
            delete invitorRelationshipInfo.inviteeIndexMap[_user];
            invitorRelationshipInfo.invitees.pop();
        }
        
        UserInfo storage invitorInfo =
            userInfo[_pid][senderRelationshipInfo.invitor];
        UserInfo storage user =
            userInfo[_pid][_user];
        if(!user.isCalculateInvitation){
            return;
        }
        user.isCalculateInvitation = false;
        uint256 inviteeToSubWeight = _originWeight.div(INVITEE_WEIGHT);
        invitorInfo.inviteeWeight = invitorInfo.inviteeWeight.sub(inviteeToSubWeight);
        if (invitorInfo.amount == 0){
            return;
        }
        PoolInfo storage pool = poolInfo[_pid];
        pool.usersTotalWeight = pool.usersTotalWeight.sub(inviteeToSubWeight);
    }

    function modifyWeightByInvitation(
        uint256 _pid,
        address _user,
        uint256 _oldOriginWeight,
        uint256 _newOriginWeight,
        uint256 _inviteeWeight,
        uint256 _existedAmount
    ) private{
        PoolInfo storage pool = poolInfo[_pid];
        InvitationInfo storage senderInfo = usersRelationshipInfo[_user];
        uint256 poolTotalWeight = pool.usersTotalWeight;
        poolTotalWeight = poolTotalWeight.sub(_oldOriginWeight).add(_newOriginWeight);
        if(_existedAmount == 0){
            poolTotalWeight = poolTotalWeight.add(_inviteeWeight);
        }     
        UserInfo storage user = userInfo[_pid][_user];
        if (!senderInfo.isWithdrawn || (_existedAmount > 0 && user.isCalculateInvitation)) {
            UserInfo storage invitorInfo = userInfo[_pid][senderInfo.invitor];
            user.isCalculateInvitation = true;
            uint256 addInviteeWeight =
                    _newOriginWeight.div(INVITEE_WEIGHT).sub(
                        _oldOriginWeight.div(INVITEE_WEIGHT)
                    );
            invitorInfo.inviteeWeight = invitorInfo.inviteeWeight.add(
                addInviteeWeight
            );
            uint256 addInvitorWeight = 
                    _newOriginWeight.div(INVITOR_WEIGHT).sub(
                        _oldOriginWeight.div(INVITOR_WEIGHT)
                    );
            
            poolTotalWeight = poolTotalWeight.add(addInvitorWeight);
            if (invitorInfo.amount > 0) {
                poolTotalWeight = poolTotalWeight.add(addInviteeWeight);
            } 
        }
        pool.usersTotalWeight = poolTotalWeight;
    }

    function verifyDescription(string memory description)
        internal
        pure
        returns (bool success)
    {
        bytes memory nameBytes = bytes(description);
        uint256 nameLength = nameBytes.length;
        require(nameLength > 0, "INVALID INPUT");
        success = true;
        bool n7;
        for (uint256 i = 0; i <= nameLength - 1; i++) {
            n7 = (nameBytes[i] & 0x80) == 0x80 ? true : false;
            if (n7) {
                success = false;
                break;
            }
        }
    }

    function getUserModifiedWeight(uint256 _pid, address _user) private view returns (uint256){
        UserInfo storage user =  userInfo[_pid][_user];
        uint256 originWeight = user.originWeight;
        uint256 modifiedWeight = originWeight.add(user.inviteeWeight);
        if(user.isCalculateInvitation){
            modifiedWeight = modifiedWeight.add(originWeight.div(INVITOR_WEIGHT));
        }
        return modifiedWeight;
    }

        // get how much token will be mined from _toBlock to _toBlock.
    function getRewardToken(uint256 _fromBlock, uint256 _toBlock) public view virtual returns (uint256){
        return calculateRewardToken(MINT_DECREASE_TERM, SHDPerBlock, startBlock, _fromBlock, _toBlock);
    }

    function calculateRewardToken(uint _term, uint256 _initialBlock, uint256 _startBlock, uint256 _fromBlock, uint256 _toBlock) private pure returns (uint256){
        if(_fromBlock > _toBlock || _startBlock > _toBlock)
            return 0;
        if(_startBlock > _fromBlock)
            _fromBlock = _startBlock;
        uint256 totalReward = 0;
        uint256 blockPeriod = _fromBlock.sub(_startBlock).add(1);
        uint256 yearPeriod = blockPeriod.div(_term);  // produce 5760 blocks per day, 2102400 blocks per year.
        for (uint256 i = 0; i < yearPeriod; i++){
            _initialBlock = _initialBlock.div(2);
        }
        uint256 termStartIndex = yearPeriod.add(1).mul(_term).add(_startBlock);
        uint256 beforeCalculateIndex = _fromBlock.sub(1);
        while(_toBlock >= termStartIndex && _initialBlock > 0){
            totalReward = totalReward.add(termStartIndex.sub(beforeCalculateIndex).mul(_initialBlock));
            beforeCalculateIndex = termStartIndex.add(1);
            _initialBlock = _initialBlock.div(2);
            termStartIndex = termStartIndex.add(_term);
        }
        if(_toBlock > beforeCalculateIndex){
            totalReward = totalReward.add(_toBlock.sub(beforeCalculateIndex).mul(_initialBlock));
        }
        return totalReward;
    }

    function getTargetTokenInSwap(IUniswapV2Pair _lpTokenSwap, address _targetToken) internal view returns (address, address, uint256){
        address token0 = _lpTokenSwap.token0();
        address token1 = _lpTokenSwap.token1();
        if(token0 == _targetToken){
            return(token0, token1, 0);
        }
        if(token1 == _targetToken){
            return(token0, token1, 1);
        }
        require(false, "invalid uniswap");
    }

    function generateOrcaleInfo(IUniswapV2Pair _pairSwap, bool _isFirstTokenEth) internal view returns(TokenPairInfo memory){
        uint256 priceTokenCumulativeLast = _isFirstTokenEth? _pairSwap.price1CumulativeLast(): _pairSwap.price0CumulativeLast();
        uint112 reserve0;
        uint112 reserve1;
        uint32 tokenBlockTimestampLast;
        (reserve0, reserve1, tokenBlockTimestampLast) = _pairSwap.getReserves();
        require(reserve0 != 0 && reserve1 != 0, 'ExampleOracleSimple: NO_RESERVES'); // ensure that there's liquidity in the pair
        TokenPairInfo memory tokenBInfo = TokenPairInfo({
            tokenToEthSwap: _pairSwap,
            isFirstTokenEth: _isFirstTokenEth,
            priceCumulativeLast: priceTokenCumulativeLast,
            blockTimestampLast: tokenBlockTimestampLast,
            price: FixedPoint.uq112x112(0),
            lastPriceUpdateHeight: block.number
        });
        return tokenBInfo;
    }

    function updateTokenOracle(TokenPairInfo storage _pairInfo) internal returns (FixedPoint.uq112x112 memory _price) {
        FixedPoint.uq112x112 memory cachedPrice = _pairInfo.price;
        if(cachedPrice._x > 0 && block.number.sub(_pairInfo.lastPriceUpdateHeight) <= updateTokenPriceTerm){
            return cachedPrice;
        }
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(address(_pairInfo.tokenToEthSwap));
        uint32 timeElapsed = blockTimestamp - _pairInfo.blockTimestampLast; // overflow is desired
        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        if(_pairInfo.isFirstTokenEth){
            _price = FixedPoint.uq112x112(uint224(price1Cumulative.sub(_pairInfo.priceCumulativeLast).div(timeElapsed)));
            _pairInfo.priceCumulativeLast = price1Cumulative;
        }     
        else{
            _price = FixedPoint.uq112x112(uint224(price0Cumulative.sub(_pairInfo.priceCumulativeLast).div(timeElapsed)));
            _pairInfo.priceCumulativeLast = price0Cumulative;
        }
        _pairInfo.price = _price;
        _pairInfo.lastPriceUpdateHeight = block.number;
        _pairInfo.blockTimestampLast = blockTimestamp;
    }

    function updateAfterModifyStartBlock(uint256 _newStartBlock) internal override{
        lastRewardBlock = _newStartBlock.sub(1);
        if(poolInfo.length > 0){
            PoolInfo storage shdPool = poolInfo[0];
            shdPool.lastDividendHeight = lastRewardBlock;
        }
    }
}
