// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/DelegatorInterface.sol";
import "./ShardingDAOMining.sol";

contract ShardingDAOMiningDelegator is DelegatorInterface, ShardingDAOMining {
    constructor(
        SHDToken _SHD,
        address _wethToken,
        address _developerDAOFund,
        address _marketingFund,
        uint256 _maxRankNumber,
        uint256 _startBlock,
        address implementation_,
        bytes memory becomeImplementationData
    ) public {
        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,uint256,uint256)",
                _SHD,
                _wethToken,
                _developerDAOFund,
                _marketingFund,
                _maxRankNumber,
                _startBlock
            )
        );
        admin = msg.sender;
        _setImplementation(implementation_, false, becomeImplementationData);
    }

    function _setImplementation(
        address implementation_,
        bool allowResign,
        bytes memory becomeImplementationData
    ) public override {
        checkAdmin();
        if (allowResign) {
            delegateToImplementation(
                abi.encodeWithSignature("_resignImplementation()")
            );
        }

        address oldImplementation = implementation;
        implementation = implementation_;

        delegateToImplementation(
            abi.encodeWithSignature(
                "_becomeImplementation(bytes)",
                becomeImplementationData
            )
        );

        emit NewImplementation(oldImplementation, implementation);
    }

    function delegateTo(address callee, bytes memory data)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
        return returnData;
    }

    /**
     * @notice Delegates execution to the implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToImplementation(bytes memory data)
        public
        returns (bytes memory)
    {
        return delegateTo(implementation, data);
    }

    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     *  There are an additional 2 prefix uints from the wrapper returndata, which we ignore since we make an extra hop.
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToViewImplementation(bytes memory data)
        public
        view
        returns (bytes memory)
    {
        (bool success, bytes memory returnData) =
            address(this).staticcall(
                abi.encodeWithSignature("delegateToImplementation(bytes)", data)
            );
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
        return abi.decode(returnData, (bytes));
    }

    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
    //  */
    fallback() external payable {
        if (msg.value > 0) return;
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);
        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())
            switch success
                case 0 {
                    revert(free_mem_ptr, returndatasize())
                }
                default {
                    return(free_mem_ptr, returndatasize())
                }
        }
    }

    function setNftShard(address _nftShard) public override {
        delegateToImplementation(
            abi.encodeWithSignature("setNftShard(address)", _nftShard)
        );
    }

    function add(
        uint256 _nftPoolId,
        IUniswapV2Pair _lpTokenSwap,
        IUniswapV2Pair _tokenToEthSwap
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "add(uint256,address,address)",
                _nftPoolId,
                _lpTokenSwap,
                _tokenToEthSwap
            )
        );
    }

    function setPriceUpdateTerm(uint256 _term) 
        public 
        override
    {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setPriceUpdateTerm(uint256)",
                _term
            )
        );
    }

    function kickEvilPoolByPid(uint256 _pid, string calldata description)
        public
        override
    {
        delegateToImplementation(
            abi.encodeWithSignature(
                "kickEvilPoolByPid(uint256,string)",
                _pid,
                description
            )
        );
    }

    function resetEvilPool(uint256 _pid)
        public
        override
    {
        delegateToImplementation(
            abi.encodeWithSignature(
                "resetEvilPool(uint256)",
                _pid
            )
        );
    }

    function setMintCoefficient(
        uint256 _nftMintWeight,
        uint256 _reserveMintWeight
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setMintCoefficient(uint256,uint256)",
                _nftMintWeight,
                _reserveMintWeight
            )
        );
    }

    function setShardPoolDividendWeight(
        uint256 _shardPoolWeight,
        uint256 _otherPoolWeight
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setShardPoolDividendWeight(uint256,uint256)",
                _shardPoolWeight,
                _otherPoolWeight
            )
        );
    }

    function setStartBlock(
        uint256 _startBlock
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setStartBlock(uint256)",
                _startBlock
            )
        );
    }

    function setSHDPerBlock(uint256 _shardPerBlock, bool _withUpdate) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setSHDPerBlock(uint256,bool)",
                _shardPerBlock,
                _withUpdate
            )
        );
    }

    function massUpdatePools() public override {
        delegateToImplementation(abi.encodeWithSignature("massUpdatePools()"));
    }

    function updatePoolDividend(uint256 _pid) public override {
        delegateToImplementation(
            abi.encodeWithSignature("updatePoolDividend(uint256)", _pid)
        );
    }

    function deposit(
        uint256 _pid,
        uint256 _amount,
        uint256 _lockTime
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "deposit(uint256,uint256,uint256)",
                _pid,
                _amount,
                _lockTime
            )
        );
    }

    function withdraw(uint256 _pid) public override {
        delegateToImplementation(
            abi.encodeWithSignature("withdraw(uint256)", _pid)
        );
    }

    function tryToReplacePoolInRank(uint256 _poolIndexInRank, uint256 _pid)
        public
        override
    {
        delegateToImplementation(
            abi.encodeWithSignature(
                "tryToReplacePoolInRank(uint256,uint256)",
                _poolIndexInRank,
                _pid
            )
        );
    }

    function acceptInvitation(address _invitor) public override {
        delegateToImplementation(
            abi.encodeWithSignature("acceptInvitation(address)", _invitor)
        );
    }

    function setMaxRankNumber(uint256 _count) public override {
        delegateToImplementation(
            abi.encodeWithSignature("setMaxRankNumber(uint256)", _count)
        );
    }

    function setDeveloperDAOFund(
    address _developer
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setDeveloperDAOFund(address)",
                _developer
            )
        );
    }

    function setDividendWeight(
        uint256 _userDividendWeight,
        uint256 _devDividendWeight
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setDividendWeight(uint256,uint256)",
                _userDividendWeight,
                _devDividendWeight
            )
        );
    }

    function setTokenAmountLimit(
        uint256 _pid, 
        uint256 _tokenAmountLimit
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setTokenAmountLimit(uint256,uint256)",
                _pid,
                _tokenAmountLimit
            )
        );
    }

    function setTokenAmountLimitFeeRate(
        uint256 _feeRateNumerator,
        uint256 _feeRateDenominator
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setTokenAmountLimitFeeRate(uint256,uint256)",
                _feeRateNumerator,
                _feeRateDenominator
            )
        );
    }

    function setContracSenderFeeRate(
        uint256 _feeRateNumerator,
        uint256 _feeRateDenominator
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setContracSenderFeeRate(uint256,uint256)",
                _feeRateNumerator,
                _feeRateDenominator
            )
        );
    }

    function transferAdmin(
        address _admin
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "transferAdmin(address)",
                _admin
            )
        );
    }

    function setMarketingFund(
        address _marketingFund
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setMarketingFund(address)",
                _marketingFund
            )
        );
    }

    function pendingSHARD(uint256 _pid, address _user)
        external
        view
        override
        returns (uint256, uint256, uint256)
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "pendingSHARD(uint256,address)",
                    _pid,
                    _user
                )
            );
        return abi.decode(data, (uint256, uint256, uint256));
    }

    function pendingSHARDByPids(uint256[] memory _pids, address _user)
        external
        view
        override
        returns (uint256[] memory _pending, uint256[] memory _potential, uint256 _blockNumber)
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "pendingSHARDByPids(uint256[],address)",
                    _pids,
                    _user
                )
            );
        return abi.decode(data, (uint256[], uint256[], uint256));
    }

    function getPoolLength() public view override returns (uint256) {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature("getPoolLength()")
            );
        return abi.decode(data, (uint256));
    }

    function getPagePoolInfo(uint256 _fromIndex, uint256 _toIndex)
        public
        view
        override
        returns (
            uint256[] memory _nftPoolId,
            uint256[] memory _accumulativeDividend,
            uint256[] memory _usersTotalWeight,
            uint256[] memory _lpTokenAmount,
            uint256[] memory _oracleWeight,
            address[] memory _swapAddress
        )
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "getPagePoolInfo(uint256,uint256)",
                    _fromIndex,
                    _toIndex
                )
            );
        return
            abi.decode(
                data,
                (
                    uint256[],
                    uint256[],
                    uint256[],
                    uint256[],
                    uint256[],
                    address[]
                )
            );
    }

    function getInstantPagePoolInfo(uint256 _fromIndex, uint256 _toIndex)
    public
    override
    returns (
        uint256[] memory _nftPoolId,
        uint256[] memory _accumulativeDividend,
        uint256[] memory _usersTotalWeight,
        uint256[] memory _lpTokenAmount,
        uint256[] memory _oracleWeight,
        address[] memory _swapAddress
    )
    {
        bytes memory data =
            delegateToImplementation(
                abi.encodeWithSignature(
                    "getInstantPagePoolInfo(uint256,uint256)",
                    _fromIndex,
                    _toIndex
                )
            );
        return
            abi.decode(
                data,
                (
                    uint256[],
                    uint256[],
                    uint256[],
                    uint256[],
                    uint256[],
                    address[]
                )
            );
    }

    function getRankList() public view override returns (uint256[] memory) {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature("getRankList()")
            );
        return abi.decode(data, (uint256[]));
    }

    function getBlackList()
        public
        view
        override
        returns (EvilPoolInfo[] memory _blackList)
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature("getBlackList()")
            );
        return abi.decode(data, (EvilPoolInfo[]));
    }

    function getInvitation(address _sender)
        public
        view
        override
        returns (
            address _invitor,
            address[] memory _invitees,
            bool _isWithdrawn
        )
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature("getInvitation(address)", _sender)
            );
        return abi.decode(data, (address, address[], bool));
    }

    function getUserInfo(uint256 _pid, address _sender)
        public
        view
        override
        returns (
            uint256 _amount,
            uint256 _originWeight,
            uint256 _modifiedWeight,
            uint256 _endBlock
        )
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "getUserInfo(uint256,address)",
                    _pid,
                    _sender
                )
            );
        return abi.decode(data, (uint256, uint256, uint256, uint256));
    }

    function getUserInfoByPids(uint256[] memory _pids, address _sender)
        public
        view
        override
        returns (
            uint256[] memory _amount,
            uint256[] memory _originWeight,
            uint256[] memory _modifiedWeight,
            uint256[] memory _endBlock
        )
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "getUserInfoByPids(uint256[],address)",
                    _pids,
                    _sender
                )
            );
        return abi.decode(data, (uint256[], uint256[], uint256[], uint256[]));
    }

    function getOracleInfo(uint256 _pid)
        public
        view
        override
        returns (
            address _swapToEthAddress,
            uint256 _priceCumulativeLast,
            uint256 _blockTimestampLast,
            uint256 _price,
            uint256 _lastPriceUpdateHeight
        )
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature("getOracleInfo(uint256)", _pid)
            );
        return abi.decode(data, (address, uint256, uint256, uint256, uint256));
    }

    function getRewardToken(uint256 _fromBlock, uint256 _toBlock)
        public
        view
        override
        returns (
            uint256
        )
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature("getRewardToken(uint256,uint256)", _fromBlock, _toBlock)
            );
        return abi.decode(data, (uint256));
    }
}
