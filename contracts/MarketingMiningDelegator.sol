// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/DelegatorInterface.sol";
import "./MarketingMining.sol";


contract MarketingMiningDelegator is DelegatorInterface, MarketingMining {
    constructor(
        address _SHARD,
        address _invitation,
        uint256 _bonusEndBlock,
        uint256 _startBlock,
        uint256 _shardPerBlock,
        address _developerDAOFund,
        address _marketingFund,
        address _weth,
        address implementation_,
        bytes memory becomeImplementationData
    ) public {
        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                "initialize(address,address,uint256,uint256,uint256,address,address,address)",
                _SHARD,
                _invitation,
                _bonusEndBlock,
                _startBlock,
                _shardPerBlock,
                _developerDAOFund,
                _marketingFund,
                _weth
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

    
    function add(
        uint256 _allocPoint,
        IERC20 _tokenAddress,
        bool _isUpdate
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "add(uint256,address,bool)",
                _allocPoint,
                _tokenAddress,
                _isUpdate
            )
        );
    }

    function setAllocationPoint(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setAllocationPoint(uint256,uint256,bool)",
                _pid,
                _allocPoint,
                _withUpdate
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

    function setIsDepositAvailable(bool _isDepositAvailable) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setIsDepositAvailable(bool)",
                _isDepositAvailable
            )
        );
    }

    function setIsRevenueWithdrawable(bool _isRevenueWithdrawable) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setIsRevenueWithdrawable(bool)",
                _isRevenueWithdrawable
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

    function massUpdatePools() public override {
        delegateToImplementation(abi.encodeWithSignature("massUpdatePools()"));
    }

    function addAvailableDividend(uint256 _amount, bool _isUpdate) public override {
        delegateToImplementation(
            abi.encodeWithSignature("addAvailableDividend(uint256,bool)", _amount, _isUpdate)
        );
    }

    function updatePoolDividend(uint256 _pid) public override {
        delegateToImplementation(
            abi.encodeWithSignature("updatePoolDividend(uint256)", _pid)
        );
    }

    function depositETH(
        uint256 _pid
    ) external payable override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "depositETH(uint256)",
                _pid
            )
        );
    }

    function deposit(
        uint256 _pid,
        uint256 _amount
    ) public override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "deposit(uint256,uint256)",
                _pid,
                _amount
            )
        );
    }

    function withdraw(uint256 _pid, uint256 _amount) public override {
        delegateToImplementation(
            abi.encodeWithSignature("withdraw(uint256,uint256)", _pid, _amount)
        );
    }

    function withdrawETH(uint256 _pid, uint256 _amount) external override {
        delegateToImplementation(
            abi.encodeWithSignature("withdrawETH(uint256,uint256)", _pid, _amount)
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

    function getMultiplier(uint256 _from, uint256 _to) public view override returns (uint256) {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature("getMultiplier(uint256,uint256)", _from, _to)
            );
        return abi.decode(data, (uint256));
    }

    function getPoolInfo(uint256 _pid) 
        public 
        view 
        override
        returns(
            uint256 _allocPoint,
            uint256 _accumulativeDividend, 
            uint256 _usersTotalWeight, 
            uint256 _tokenAmount, 
            address _tokenAddress, 
            uint256 _accs)
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "getPoolInfo(uint256)",
                    _pid
                )
            );
            return
            abi.decode(
                data,
                (
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    address,
                    uint256
                )
            );
    }

    function getPagePoolInfo(uint256 _fromIndex, uint256 _toIndex)
        public
        view
        override
        returns (
            uint256[] memory _allocPoint,
            uint256[] memory _accumulativeDividend, 
            uint256[] memory _usersTotalWeight, 
            uint256[] memory _tokenAmount, 
            address[] memory _tokenAddress, 
            uint256[] memory _accs
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
                    address[],
                    uint256[]
                )
            );
    }

    function getUserInfoByPids(uint256[] memory _pids,  address _user)
        public
        view
        override
        returns (
            uint256[] memory _amount,
            uint256[] memory _modifiedWeight, 
            uint256[] memory _revenue, 
            uint256[] memory _userDividend, 
            uint256[] memory _rewardDebt
        )
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "getUserInfoByPids(uint256[],address)",
                    _pids,
                    _user
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
                    uint256[]
                )
            );
    }
}
