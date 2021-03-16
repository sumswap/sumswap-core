
pragma solidity >=0.5.16;

import './interfaces/ISumswapV2Factory.sol';
import './SumswapV2Pair.sol';

contract SumswapV2Factory is ISumswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;
    address public migrator;
    address public route;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external virtual override view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external virtual override returns (address pair) {
        require(msg.sender == route || msg.sender == migrator, 'sumswapV2: need privilege');
        require(tokenA != tokenB, 'SumswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SumswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'SumswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(SumswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISumiswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external virtual override {
        require(msg.sender == feeToSetter, 'SumswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setMigrator(address _migrator) external virtual {
        require(msg.sender == feeToSetter, 'SumswapV2: FORBIDDEN');
        migrator = _migrator;
    }

    function setRoute(address _route) external virtual {
        require(msg.sender == feeToSetter, 'SumswapV2: FORBIDDEN');
        route = _route;
    }

    function setFeeToSetter(address _feeToSetter) external virtual override {
        require(msg.sender == feeToSetter, 'SumswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
