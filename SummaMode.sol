
pragma solidity ^0.6.0;

import "./interfaces/IERC20Sumswap.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract SummaPriContract is AccessControl {

    function node_count() external virtual returns (uint256);

    function node_switch() external virtual returns (bool);

    function nodeReceiveAddress() external virtual returns (address);

    function node_time() external virtual returns (uint256);

    function getRelation(address addr) external virtual returns (address);

    function getInvitor(address addr) external virtual returns (uint256);

    function addNode(address addr) external virtual returns (bool);
}

contract SummaMode is Ownable {

    using Address for address;

    using SafeMath for uint256;

    struct PlaceType {
        address token;
        // how much token for summa (10000 -> 1)
        uint256 price;
        // seconds
        uint256 duration;
        uint256 minTurnOver;
        uint256 placeFeeRate;
    }

    bytes32 public constant ANGEL_ROLE = keccak256("ANGEL_ROLE");

    bytes32 public constant INITIAL_ROLE = keccak256("INITIAL_ROLE");

    bytes32 public constant INVITE_ROLE = keccak256("INVITE_ROLE");

    bytes32 public constant NODE_ROLE = keccak256("NODE_ROLE");

    bytes32 public constant PUBLIC_ROLE = keccak256("PUBLIC_ROLE");

    address public summaPri;

    address public summa;

    mapping(address => uint256) public _priBalances;

    mapping(address => uint256) public _pubBalances;
    //  --------------------------produce------------------------
    //    PlaceType public priPlaceType = PlaceType({
    //    token : address(0),
    //    price : 0.5 * 10000,
    //    duration : 60 * 24 * 225,
    //    minTurnOver : 10000,
    //    placeFeeRate : 0.2 * 1000
    //    });
    //
    //    uint256 public pub_count = 3000;
    //    // 16M summa
    //    uint256 public pub_total_summa = 16000000;
    //
    //    PlaceType public pubPlaceType = PlaceType({
    //    token : address(0),
    //    price : 0.75 * 10000,
    //    duration : 90 * 24 * 225,
    //    minTurnOver : 4000,
    //    placeFeeRate : 0.2 * 1000
    //    });
    // ----------------------produce--------------------------

    //  --------------------------dev------------------------
    PlaceType public priPlaceType = PlaceType({
    token : address(0),
    price : 0.5 * 10000,
    duration : 2 * 225,
    minTurnOver : 10000,
    placeFeeRate : 0.2 * 1000
    });

    uint256 public pub_count = 12;
    // 16M summa
    uint256 public pub_total_summa = 64000;

    PlaceType public pubPlaceType = PlaceType({
    token : address(0),
    price : 0.75 * 10000,
    duration : 3 * 225,
    minTurnOver : 4000,
    placeFeeRate : 0.2 * 1000
    });
    // ----------------------dev--------------------------
    bool public pub_switch = false;

    uint256 public pub_time = 0;

    // received pubToken amount
    uint256 public pubTokenAmount = 0;

    uint256 public minBackAmount = 50;

    uint256 public pubSum = 0;


    mapping(address => bool) private hasPri;

    constructor(address addrSP, address addrS) public payable {
        summaPri = addrSP;
        summa = addrS;
    }

    function priBalanceOf(address account) public view returns (uint256) {
        return _priBalances[account];
    }

    function pubBalanceOf(address account) public view returns (uint256) {
        if ((!pub_switch || block.number > pub_time.add(pubPlaceType.duration) || pub_count <= 0) && pubTokenAmount > 0) {
            uint256 realPrice = pubTokenAmount.div(pub_total_summa).mul(10000).div(10 ** uint256(IERC20Sumswap(pubPlaceType.token).decimals()));
            if (realPrice > pubPlaceType.price) {
                return _pubBalances[account].mul(10 ** uint256(IERC20Sumswap(summa).decimals())).div(pubTokenAmount.div(pub_total_summa));
            }
            return _pubBalances[account].mul(10 ** uint256(IERC20Sumswap(summa).decimals())).div(pubPlaceType.price.mul(10 ** uint256(IERC20Sumswap(pubPlaceType.token).decimals())).div(10000));
        }
        return 0;
    }

    function realPrice() public view returns (uint256){
        if ((!pub_switch || block.number > pub_time.add(pubPlaceType.duration) || pub_count <= 0) && pubTokenAmount > 0) {
            return pubTokenAmount.div(pub_total_summa).mul(10000).div(10 ** uint256(IERC20Sumswap(pubPlaceType.token).decimals()));
        }
        return 0;
    }

    function updateSumma(address addr) public onlyOwner {
        summa = addr;
    }

    function updateSummaPri(address addr) public onlyOwner {
        summaPri = addr;
    }

    function updatePriToken(address addr) public onlyOwner {
        require(addr.isContract(), "must be contract addr");
        priPlaceType.token = addr;
    }

    function updatePubToken(address addr) public onlyOwner {
        require(addr.isContract(), "must be contract addr");
        pubPlaceType.token = addr;
    }

    function updatePriType(address addr, uint256 price, uint256 duration, uint256 minTurnOver, uint256 placeFeeRate) public onlyOwner {
        require(addr.isContract(), "must be contract addr");
        priPlaceType.token = addr;
        priPlaceType.duration = duration;
        priPlaceType.minTurnOver = minTurnOver;
        priPlaceType.price = price;
        priPlaceType.placeFeeRate = placeFeeRate;
    }

    function updatePubType(address addr, uint256 price, uint256 duration, uint256 minTurnOver, uint256 placeFeeRate) public onlyOwner {
        require(addr.isContract(), "must be contract addr");
        pubPlaceType.token = addr;
        pubPlaceType.duration = duration;
        pubPlaceType.minTurnOver = minTurnOver;
        pubPlaceType.price = price;
        pubPlaceType.placeFeeRate = placeFeeRate;
    }

    /*to approve token before use this func*/
    function privatePlacement(uint256 amount) public {
        require(amount > 0, "amount must be gt 0");
        require(IERC20Sumswap(priPlaceType.token).allowance(_msgSender(), address(this)) > 0, "allowance not enough");
        //        require(IERC20Sumswap(priPlaceType.token).balanceOf(_msgSender()) >= IERC20Sumswap(priPlaceType.token).allowance(_msgSender(), address(this)), "balance not enough");
        bool fullNode = SummaPriContract(summaPri).getRoleMemberCount(NODE_ROLE) >= SummaPriContract(summaPri).node_count() ? true : false;
        uint256 actualTurnOver = priPlaceType.minTurnOver * 10 ** uint256(IERC20Sumswap(priPlaceType.token).decimals());
        if (!hasPri[_msgSender()] && !(Address.isContract(_msgSender())) && !fullNode && SummaPriContract(summaPri).node_switch() && block.number <= SummaPriContract(summaPri).node_time().add(priPlaceType.duration) && actualTurnOver <= amount) {
            if (SummaPriContract(summaPri).addNode(_msgSender())) {
                _priBalances[_msgSender()] = priPlaceType.minTurnOver.mul(10000).div(priPlaceType.price).mul(10 ** uint256(IERC20Sumswap(summa).decimals()));
                hasPri[_msgSender()] = true;
                if (SummaPriContract(summaPri).getRoleMemberCount(NODE_ROLE) >= SummaPriContract(summaPri).node_count()) {
                    pub_switch = true;
                    pub_time = block.number;
                }
            }
            IERC20Sumswap(priPlaceType.token).transferFrom(_msgSender(), SummaPriContract(summaPri).nodeReceiveAddress(), amount);
        } else {
            if (amount >= (minBackAmount * 10 ** uint256(IERC20Sumswap(priPlaceType.token).decimals()))) {
                IERC20Sumswap(priPlaceType.token).transferFrom(_msgSender(), SummaPriContract(summaPri).nodeReceiveAddress(), amount.mul(priPlaceType.placeFeeRate).div(1000));
            } else {
                IERC20Sumswap(priPlaceType.token).transferFrom(_msgSender(), SummaPriContract(summaPri).nodeReceiveAddress(), amount);
            }
        }
    }


    /*to approve token before use this func*/
    function publicPlacement(uint256 amount) public {
        require(amount > 0, "amount must be gt 0");
        require(IERC20Sumswap(pubPlaceType.token).allowance(_msgSender(), address(this)) > 0, "allowance not enough");
        require(IERC20Sumswap(pubPlaceType.token).allowance(_msgSender(), address(this)) >= amount, "please approve allowance for this contract");
        require(SummaPriContract(summaPri).node_time() > 0, "not start");
        //        require(IERC20Sumswap(pubPlaceType.token).balanceOf(_msgSender()) >= IERC20Sumswap(pubPlaceType.token).allowance(_msgSender(), address(this)), "balance not enough");
        bool closeNode = (block.number >= SummaPriContract(summaPri).node_time().add(priPlaceType.duration) || SummaPriContract(summaPri).getRoleMemberCount(NODE_ROLE) >= SummaPriContract(summaPri).node_count()) ? true : false;
        if (closeNode && !pub_switch) {
            pub_switch = true;
            pub_time = block.number;
        }
        uint256 actualTurnOver = pubPlaceType.minTurnOver * 10 ** uint256(IERC20Sumswap(pubPlaceType.token).decimals());
        if (!(Address.isContract(_msgSender())) && closeNode && block.number <= pub_time.add(pubPlaceType.duration) && pub_switch && pub_count > 0 && actualTurnOver <= amount) {
            if (SummaPriContract(summaPri).hasRole(PUBLIC_ROLE, _msgSender())) {
                if (_pubBalances[_msgSender()] <= 0) {
                    pub_count = pub_count.sub(1);
                    pubSum = pubSum.add(1);
                    if (pub_count <= 0) {
                        pub_switch = false;
                    }
                }
                pubTokenAmount = pubTokenAmount.add(amount);
                _pubBalances[_msgSender()] = _pubBalances[_msgSender()].add(amount);
            }
            IERC20Sumswap(pubPlaceType.token).transferFrom(_msgSender(), address(this), amount);
        } else {
            if (amount < (minBackAmount * 10 ** uint256(IERC20Sumswap(priPlaceType.token).decimals()))) {
                IERC20Sumswap(priPlaceType.token).transferFrom(_msgSender(), address(this), amount);
            } else {
                IERC20Sumswap(pubPlaceType.token).transferFrom(_msgSender(), address(this), amount.mul(pubPlaceType.placeFeeRate).div(1000));
            }
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