
pragma solidity >=0.6.6;

import "./interfaces/ISumiswapV2Pair.sol";
import "./interfaces/ISumswapV2Factory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Migrator is Ownable{
    address public chef;
    ISumswapV2Factory public factory;
    uint256 public notBeforeTime;
    uint256 public desiredLiquidity = uint256(-1);
    bool public switchOn = false;

    constructor(
        address _chef,
        ISumswapV2Factory _factory
    ) public {
        chef = _chef;
        factory = _factory;
    }

    function migrate(ISumiswapV2Pair orig) public returns (ISumiswapV2Pair) {
        require(msg.sender == chef, "not from master chef");
        require(switchOn == true, "must be switch true");
        require(orig.factory() != address(factory), "not from diff factory");
        address token0 = orig.token0();
        address token1 = orig.token1();
        ISumiswapV2Pair pair = ISumiswapV2Pair(factory.getPair(token0, token1));
        if (pair == ISumiswapV2Pair(address(0))) {
            pair = ISumiswapV2Pair(factory.createPair(token0, token1));
        }
        uint256 lp = orig.balanceOf(msg.sender);
        if (lp == 0) return pair;
        desiredLiquidity = lp;
        orig.transferFrom(msg.sender, address(orig), lp);
        orig.burn(address(pair));
        pair.mint(msg.sender);
        desiredLiquidity = uint256(-1);
        return pair;
    }

    function setSwitchOn() public onlyOwner {
        switchOn = true;
    }
}