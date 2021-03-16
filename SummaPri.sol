
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IERC20Sumswap.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract SummaPri is AccessControl {

    using SafeMath for uint256;

    using Address for address;

    bytes32 public constant ANGEL_ROLE = keccak256("ANGEL_ROLE");

    bytes32 public constant INITIAL_ROLE = keccak256("INITIAL_ROLE");

    bytes32 public constant INVITE_ROLE = keccak256("INVITE_ROLE");

    bytes32 public constant NODE_ROLE = keccak256("NODE_ROLE");

    bytes32 public constant PUBLIC_ROLE = keccak256("PUBLIC_ROLE");

    bytes32 public constant TRANS_ROLE = keccak256("TRANS_ROLE");
    // ----------------produce------------
//    uint256 public angel_count = 15;
//
//    uint256 public initial_count = 3000;
//
//    uint256 public invite_count = 3000;
//
//    uint256 public node_count = 400;
//
//    uint256 public invitor_count = 10;
    // ----------------produce------------

    // ----------------dev------------
    uint256 public angel_count = 3;

    uint256 public initial_count = 15;

    uint256 public invite_count = 15;

    uint256 public node_count = 8;

    uint256 public invitor_count = 2;
    // ----------------dev------------


    uint256 public initial_threshold = 0.1 * 10 ** 18;

    uint256 public initial_after_threshold = 0.01 * 10 ** 18;

    bool public pri_switch = true;

    bool public inviter_switch = true;

    bool public node_switch = false;

    address public nodeReceiveAddress;

    uint256 public priSum = 0;

    uint256 public node_time = 0;

    address public summa;

    address public summaMode;

    /*
    key current address
    value parent address
    */
    mapping(address => address) private relations;

    mapping(address => uint256) private invitor;

    constructor(address summaAddr) public payable{
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        nodeReceiveAddress = _msgSender();
        summa = summaAddr;
    }

    function getRelation(address addr) public view returns (address){
        return relations[addr];
    }

    function getInvitor(address addr) public view returns (uint256){
        return invitor[addr];
    }

    function inviteCompetition(address from, address to) public {
        if (relations[from] == address(0) && _msgSender() == summa && !hasRole(ANGEL_ROLE, from)) {
            if(hasRole(PUBLIC_ROLE, to) && !hasRole(PUBLIC_ROLE, from)){
                relations[from] = to;
                _setupRole(PUBLIC_ROLE, from);
                invitor[to] = invitor[to].add(1);
            }
            if (inviter_switch && hasRole(PUBLIC_ROLE, to)) {
                if (invitor[to] >= invitor_count && !hasRole(INVITE_ROLE, to)) {
                    _setupRole(INVITE_ROLE, to);
                    if(!node_switch && node_time <= 0){
                        node_switch = true;
                        node_time = block.number;
                    }

                }
            }
        }
    }

    function addNode(address addr) public returns (bool){
        if (node_switch && _msgSender() == summaMode && hasRole(INVITE_ROLE, addr) && !hasRole(NODE_ROLE, addr)) {
            _setupRole(NODE_ROLE, addr);
            if (getRoleMemberCount(NODE_ROLE) >= node_count) {
                node_switch = false;
                inviter_switch = false;
            }
            return true;
        }
        return false;
    }

    function privateRule() internal {
        if (!hasRole(ANGEL_ROLE, _msgSender()) && getRoleMemberCount(ANGEL_ROLE) < angel_count) {
            _setupRole(ANGEL_ROLE, _msgSender());
            _setupRole(INITIAL_ROLE, _msgSender());
            _setupRole(PUBLIC_ROLE, _msgSender());
        }
        if (!hasRole(INITIAL_ROLE, _msgSender()) && getRoleMemberCount(INITIAL_ROLE) < initial_count) {
            _setupRole(INITIAL_ROLE, _msgSender());
        }
    }

    function updateInitialThreshold(uint256 amount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        initial_threshold = amount;
    }

    function updateSumma(address contractAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        summa = contractAddress;
    }

    function updatePriSwitch(bool _switch) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        pri_switch = _switch;
    }

    function updateSummaMode(address contractAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        summaMode = contractAddress;
    }

    function updateNodeReceiveAddress(address addr) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        nodeReceiveAddress = addr;
    }

    function updateInitialAfterThreshold(uint256 amount) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        initial_after_threshold = amount;
    }

    function withdrawETH() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        msg.sender.transfer(address(this).balance);
    }

    function withdrawToken(address addr) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not a admin");
        IERC20Sumswap(addr).transfer(_msgSender(), IERC20Sumswap(addr).balanceOf(address(this)));
    }

    function prePrivateRule() internal {
        if (getRoleMemberCount(INITIAL_ROLE) < initial_count) {
            if (msg.value >= initial_threshold) {
                privateRule();
                IERC20Sumswap(summa).transfer(_msgSender(), 5 * 10 ** 18);
                priSum = priSum.add(1);
            }
        } else {
            if (msg.value >= initial_after_threshold) {
                IERC20Sumswap(summa).transfer(_msgSender(), 0.1 * 10 ** 18);
                priSum = priSum.add(1);
            }
        }
    }

    receive() external payable {
        if (!(Address.isContract(_msgSender())) && pri_switch) {
            prePrivateRule();
        }
    }
}