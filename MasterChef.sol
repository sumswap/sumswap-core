
pragma solidity >=0.6.6;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAccessControl.sol";

interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}

interface ITokenIssue {
    function transByContract(address to, uint256 amount) external;

    function issueInfo(uint256 monthIndex) external view returns (uint256);

    function startIssueTime() external view returns (uint256);

    function issueInfoLength() external view returns (uint256);

    function TOTAL_AMOUNT() external view returns (uint256);

    function DAY_SECONDS() external view returns (uint256);

    function MONTH_SECONDS() external view returns (uint256);

    function INIT_MINE_SUPPLY() external view returns (uint256);
}

// MasterChef is the master of Summa. He can make Summa and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once SUMMA is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes32 public constant PUBLIC_ROLE = keccak256("PUBLIC_ROLE");

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SUMMAs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSUMMAPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSUMMAPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. SUMMAs to distribute per block.
        uint256 lastRewardTime;  // Last seconds that SUMMAs distribution occurs.
        uint256 accSummaPerShare; // Accumulated SUMMAs per share, times 1e12. See below.
    }

    // The SUMMA TOKEN!
    IERC20 public summa;
    // Block number when bonus SUMMA period ends.
    uint256 public bonusEndTime;
    // Bonus muliplier for early summa makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    IAccessControl public accessContract;

    ITokenIssue public tokenIssue;

    uint256 public totalIssueRate = 0.2 * 10000;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when SUMMA mining starts.
    uint256 public startTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IERC20 _summa,
        uint256 _startTime,
        uint256 _bonusEndTime,
        IAccessControl _accessContract
    ) public {
        summa = _summa;
        bonusEndTime = _bonusEndTime;
        startTime = _startTime;
        accessContract = _accessContract;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        // avoid to add not erc20
        _lpToken.totalSupply();

        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime = block.number > startTime ? block.number : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        lastRewardTime : lastRewardTime,
        accSummaPerShare : 0
        }));
    }

    // Update the given pool's SUMMA allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    function setTokenIssue(ITokenIssue _tokenIssue) public onlyOwner {
        tokenIssue = _tokenIssue;
    }

    function setTotalIssueRate(uint256 _totalIssueRate) public onlyOwner {
        totalIssueRate = _totalIssueRate;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
//        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 issueTime = tokenIssue.startIssueTime();
        if (_to <= bonusEndTime) {
            if (_to < issueTime) {
                return 0;
            }
            if (_from < issueTime) {
                return getIssue(issueTime, _to).mul(totalIssueRate).div(10000).mul(BONUS_MULTIPLIER);
            }
            return getIssue(issueTime, _to).sub(getIssue(issueTime, _from)).mul(totalIssueRate).div(10000).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndTime) {
            if (_to < issueTime) {
                return 0;
            }
            if (_from < issueTime) {
                return getIssue(issueTime, _to).mul(totalIssueRate).div(10000);
            }
            return getIssue(issueTime, _to).sub(getIssue(issueTime, _from)).mul(totalIssueRate).div(10000);
        } else {
            if (_to < issueTime) {
                return 0;
            }
            if (_from < issueTime) {
                if(issueTime < bonusEndTime){
                    return getIssue(issueTime,bonusEndTime).mul(BONUS_MULTIPLIER).add(
                        getIssue(issueTime, _to).sub(getIssue(issueTime, bonusEndTime))
                    ).mul(totalIssueRate).div(10000);
                }
                return getIssue(issueTime, _to);
            }
            return getIssue(issueTime, bonusEndTime).sub(getIssue(issueTime, _from)).mul(BONUS_MULTIPLIER).add(
                getIssue(issueTime,_to).sub(getIssue(issueTime,bonusEndTime))
            ).mul(totalIssueRate).div(10000);

        }
    }

    function getIssue(uint256 _from, uint256 _to) private view returns (uint256){
        if (_to <= _from || _from <= 0) {
            return 0;
        }
        uint256 timeInterval = _to - _from;
        uint256 monthIndex = timeInterval.div(tokenIssue.MONTH_SECONDS());
        if (monthIndex < 1) {
            return timeInterval.mul(tokenIssue.issueInfo(monthIndex).div(tokenIssue.MONTH_SECONDS()));
        } else if (monthIndex < tokenIssue.issueInfoLength()) {
            uint256 tempTotal = 0;
            for (uint256 j = 0; j < monthIndex; j++) {
                tempTotal = tempTotal.add(tokenIssue.issueInfo(j));
            }
            uint256 calcAmount = timeInterval.sub(monthIndex.mul(tokenIssue.MONTH_SECONDS())).mul(tokenIssue.issueInfo(monthIndex).div(tokenIssue.MONTH_SECONDS())).add(tempTotal);
            if (calcAmount > tokenIssue.TOTAL_AMOUNT().sub(tokenIssue.INIT_MINE_SUPPLY())) {
                return tokenIssue.TOTAL_AMOUNT().sub(tokenIssue.INIT_MINE_SUPPLY());
            }
            return calcAmount;
        } else {
            return 0;
        }
    }

    // View function to see pending SUMMAs on frontend.
    function pendingSumma(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSummaPerShare = pool.accSummaPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.number);
            uint256 summaReward = multiplier.mul(pool.allocPoint).div(totalAllocPoint);
            accSummaPerShare = accSummaPerShare.add(summaReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accSummaPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.number);
        uint256 summaReward = multiplier.mul(pool.allocPoint).div(totalAllocPoint);
        tokenIssue.transByContract(address(this), summaReward);
        pool.accSummaPerShare = pool.accSummaPerShare.add(summaReward.mul(1e12).div(lpSupply));
        pool.lastRewardTime = block.number;
    }

    // Deposit LP tokens to MasterChef for SUMMA allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        require(accessContract.hasRole(PUBLIC_ROLE,address(msg.sender)),"not permit");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSummaPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeSummaTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSummaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accSummaPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeSummaTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            if(_amount < pool.lpToken.balanceOf(address(this))){
                user.amount = user.amount.sub(_amount);
                pool.lpToken.safeTransfer(address(msg.sender), _amount);
            }else{
                user.amount = 0;
                pool.lpToken.safeTransfer(address(msg.sender), pool.lpToken.balanceOf(address(this)));
            }
        }
        user.rewardDebt = user.amount.mul(pool.accSummaPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        if(pool.lpToken.balanceOf(address(this)) < user.amount){
            amount = pool.lpToken.balanceOf(address(this));
        }
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe summa transfer function, just in case if rounding error causes pool to not have enough SUMMAs.
    function safeSummaTransfer(address _to, uint256 _amount) internal {
        uint256 summaBal = summa.balanceOf(address(this));
        if (_amount > summaBal) {
            summa.transfer(_to, summaBal);
        } else {
            summa.transfer(_to, _amount);
        }
    }
}
