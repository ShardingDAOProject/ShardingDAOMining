// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract UniswapV2PairOfPool2 is IUniswapV2Pair{
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    address public ethToken;
    constructor(address _ethTokenAddress) public{
        ethToken = _ethTokenAddress;
    }

    function name() external pure override returns (string memory){
        return 'pool2';
    }

    function symbol() external pure override returns (string memory){
        return 'SJUNE';
    }
    function decimals() external pure override returns (uint8){
        return 1;
    }
    function totalSupply() external view override returns (uint){
        return 10000;
    }
    function balanceOf(address owner) external view override returns (uint){
        return 10000;
    }
    function allowance(address owner, address spender) external view override returns (uint){
        return 10000;
    }

    function approve(address spender, uint value) external override returns (bool){
        return true;
    }
    function transfer(address to, uint value) external override returns (bool){
        return true;
    }
    function transferFrom(address from, address to, uint value) external override returns (bool){
        return true;
    }

    function DOMAIN_SEPARATOR() external view override returns (bytes32){
        uint a = 1;
        return bytes32(a);
    }
    function PERMIT_TYPEHASH() external pure override returns (bytes32){
        uint a = 1;
        return bytes32(a);
    }
    function nonces(address owner) external view override returns (uint){
        return 0;
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external override{

    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure override returns (uint){
        return 8;
    }
    function factory() external view override returns (address){
        return address(0);
    }
    function token0() external view override returns (address){
        return ethToken;
    }
    function token1() external view override returns (address){
        return address(0);
    }
    function getReserves() external view override returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast){
        return (100000000,100000000,1);
    }
    function price0CumulativeLast() external view override returns (uint){
        return 10;
    }
    function price1CumulativeLast() external view override returns (uint){
        return 10;
    }
    function kLast() external view override returns (uint){
        return 8;
    }

    function mint(address to) external override returns (uint liquidity){
        return 8;
    }
    function burn(address to) external override returns (uint amount0, uint amount1){
        return (1,1);
    }
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override{

    }
    function skim(address to) external override{

    }
    function sync() external override{

    }

    function initialize(address, address) external override{
        
    }
}