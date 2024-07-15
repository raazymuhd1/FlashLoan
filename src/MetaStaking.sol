// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MetaStaking {

    // stake for 600 days and earn 0.5% rewards in USDT
    mapping(address user => uint256 staked) private userStaked;
    mapping(address => Stake) public stakes;

    uint256 private s_totalStaked;

    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    event Staked(address indexed staker, uint256 amount, uint256 startTime);
    event Unstaked(address indexed staker, uint256 amount, uint256 reward);

    uint256 public constant stakingDuration = 600 days;
    uint256 public annualInterestRate = 1; // 5% annual interest rate

    // Stake tokens
    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(stakes[msg.sender].amount == 0, "You already have an active stake");

        // Transfer tokens to the contract
        // Assume the ERC20 token is already approved to spend by the staker
        // token.transferFrom(msg.sender, address(this), _amount);

        stakes[msg.sender] = Stake({
            amount: _amount,
            startTime: block.timestamp
        });

        emit Staked(msg.sender, _amount, block.timestamp);
    }

    // Unstake tokens and claim rewards
    function unstake() external {
        require(stakes[msg.sender].amount > 0, "You don't have an active stake");

        uint256 stakeAmount = stakes[msg.sender].amount;
        uint256 startTime = stakes[msg.sender].startTime;
        uint256 reward = calculateReward(stakeAmount, startTime);

        // Transfer tokens back to the staker
        // token.transfer(msg.sender, stakeAmount + reward);

        // Clear stake
        delete stakes[msg.sender];

        emit Unstaked(msg.sender, stakeAmount, reward);
    }

    // Calculate the reward based on the staking duration and annual interest rate
    function calculateReward(uint256 _amount, uint256 _startTime) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - _startTime;
        uint256 timeFraction = timeElapsed / stakingDuration;

        return (_amount * annualInterestRate / 100) * timeFraction;
    }
}
