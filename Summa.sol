
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ISummaPri {
     function inviteCompetition(address from, address to) external;
}

contract Summa is ERC20, Ownable {

    using Address for address;

    address public summaPri;

    uint256 public invite_amount = 0.01 * 10 ** 18;

    address public tokenIssue;

    constructor(uint256 initialSupply) public ERC20("SUM", "SUM") payable{
        _mint(_msgSender(), initialSupply);
    }

    function mine(address addr, uint256 amount) public onlyOwner {
        _mint(addr, amount);
    }

    function issue(address addr, uint256 amount) public {
        require(_msgSender() == tokenIssue,"caller not allowed");
        _mint(addr, amount);
    }

    function burn(address addr, uint256 amount) public onlyOwner {
        _burn(addr, amount);
    }

    function updateSummaPri(address addr) public onlyOwner {
        summaPri = addr;
    }

    function updateTokenIssue(address addr) public onlyOwner {
        tokenIssue = addr;
    }

    function updateInviteAmount(uint256 amount) public onlyOwner {
        invite_amount = amount;
    }

    function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual override {
        if(!(to.isContract()) && !(from.isContract()) && summaPri != address(0) && value >= invite_amount){
            ISummaPri(summaPri).inviteCompetition(from,to);
        }
        super._beforeTokenTransfer(from, to, value);
    }

    function withdrawETH() public onlyOwner{
        msg.sender.transfer(address(this).balance);
    }

    function withdrawToken(address addr) public onlyOwner{
        ERC20(addr).transfer(_msgSender(), ERC20(addr).balanceOf(address(this)));
    }

    receive() external payable {
    }
}