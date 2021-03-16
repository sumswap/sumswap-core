
pragma solidity ^0.6.0;

import "./interfaces/IERC20Sumswap.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface ISummaMode {
    function priBalanceOf(address account) external view returns (uint256);
    function pubBalanceOf(address account) external view returns (uint256);
}

contract Release is Ownable {

    using SafeMath for uint256;
    address public summaMode;
    address public summa;
    mapping(address => uint256) private withDraw;
    bool public releaseSwitch;
    bool public firstReleaseSwitch;
    uint256 public startTime = 1;

    uint256 public duration = 5400;

    constructor(address addrMode, address addrSumma) public payable{
        summaMode = addrMode;
        summa = addrSumma;
    }

    function setReleaseSwitchOpen() public onlyOwner {
        if (!releaseSwitch) {
            releaseSwitch = true;
            startTime = block.number;
        }
    }

    function setFirstReleaseSwitchOpen() public onlyOwner {
        if (!firstReleaseSwitch) {
            firstReleaseSwitch = true;
        }
    }

    function unReleaseOf(address addr) public view returns (uint256){
        return ISummaMode(summaMode).priBalanceOf(addr).add(ISummaMode(summaMode).pubBalanceOf(addr)).sub(releasedOf(addr));
    }

    function releasedOf(address addr) public view returns (uint256){
        uint256 balance = ISummaMode(summaMode).priBalanceOf(addr).add(ISummaMode(summaMode).pubBalanceOf(addr));
        if(firstReleaseSwitch && startTime == 1){
            return balance.mul(10).div(100);
        } else if (releaseSwitch && block.number >= startTime && startTime != 1) {
            uint256 dayNum = block.number - startTime;
            if (dayNum >= 486000) {
                return balance;
            }else {
                uint256 tempBalance = balance.mul(10).div(100).add(dayNum.div(duration).mul(balance.div(100)));
                if(tempBalance > balance){
                    return balance;
                }
                return tempBalance;
            }
        } else {
            return 0;
        }
    }

    function releasedSubWithDrawOf(address addr) public view returns (uint256){
        return releasedOf(addr).sub(withDraw[addr]);
    }

    function withDrawSumma() public {
        uint tempBalance = releasedSubWithDrawOf(_msgSender());
        if (tempBalance > 0) {
            withDraw[_msgSender()] = withDraw[_msgSender()].add(tempBalance);
            IERC20Sumswap(summa).transfer(_msgSender(), tempBalance);
        }
    }

    function withdrawETH() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function withdrawToken(address addr) public onlyOwner {
        IERC20Sumswap(addr).transfer(_msgSender(), IERC20Sumswap(addr).balanceOf(address(this)));
    }

    receive() external payable {
    }
}