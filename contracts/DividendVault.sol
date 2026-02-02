// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title DividendVault
 * @dev A simple MVP Dividend Vault for Molt_Launch.
 * Allows depositing ETH or ERC20 tokens as revenue.
 * Token holders can claim their share based on their holdings at the time of deposit.
 * 
 * NOTE: This is an MVP implementation using a "Points" or "Shares" system
 * where the "shares" are represented by the Molt Token balance.
 * For a production system with frequently changing balances, a Snapshot approach
 * (ERC20Snapshot) or a Staking mechanism is recommended to avoid gaming the system.
 * 
 * This simplified version assumes users must STAKE their tokens in this contract
 * to be eligible for dividends, ensuring accurate tracking of "shares".
 */
contract DividendVault is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // The Molt Launch Token
    IERC20 public moltToken;

    // Total staked tokens
    uint256 public totalStaked;

    // Mapping of user stake balance
    mapping(address => uint256) public stakes;

    // Magnifier to handle precision loss
    uint256 private constant MAGNITUDE = 2**128;

    // Accumulator for ETH dividends per share
    uint256 public pointsPerShareETH;

    // Mapping for other ERC20 dividends: tokenAddress => pointsPerShare
    mapping(address => uint256) public pointsPerShareERC20;

    // Correction mappings to ensure users only get dividends starting from when they staked
    mapping(address => int256) public pointsCorrectionETH;
    mapping(address => mapping(address => int256)) public pointsCorrectionERC20;

    // Track withdrawn dividends to prevent double claiming (optional in this pattern but good for analytics)
    mapping(address => uint256) public withdrawnETH;
    mapping(address => mapping(address => uint256)) public withdrawnERC20;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event DepositETH(address indexed sender, uint256 amount);
    event DepositERC20(address indexed sender, address indexed token, uint256 amount);
    event ClaimedETH(address indexed user, uint256 amount);
    event ClaimedERC20(address indexed user, address indexed token, uint256 amount);

    constructor(address _moltToken) {
        moltToken = IERC20(_moltToken);
    }

    /**
     * @dev Deposit ETH as revenue to be distributed to stakers.
     */
    receive() external payable {
        distributeETH();
    }

    function distributeETH() public payable {
        if (totalStaked > 0 && msg.value > 0) {
            pointsPerShareETH = pointsPerShareETH.add(
                (msg.value).mul(MAGNITUDE).div(totalStaked)
            );
            emit DepositETH(msg.sender, msg.value);
        }
    }

    /**
     * @dev Deposit ERC20 tokens as revenue.
     * Caller must approve this contract to spend _amount.
     */
    function distributeERC20(address _token, uint256 _amount) external nonReentrant {
        require(_token != address(moltToken), "Cannot distribute staking token");
        require(_amount > 0, "Amount must be > 0");
        require(totalStaked > 0, "No stakers to distribute to");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        pointsPerShareERC20[_token] = pointsPerShareERC20[_token].add(
            _amount.mul(MAGNITUDE).div(totalStaked)
        );

        emit DepositERC20(msg.sender, _token, _amount);
    }

    /**
     * @dev Stake Molt Tokens to earn dividends.
     */
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0");

        moltToken.transferFrom(msg.sender, address(this), _amount);

        _distributePendingETH(msg.sender);
        // _distributePendingERC20(msg.sender, ...); // Ideally we iterate supported tokens or let users claim manually

        totalStaked = totalStaked.add(_amount);
        stakes[msg.sender] = stakes[msg.sender].add(_amount);

        // Adjust correction so they don't claim past dividends
        pointsCorrectionETH[msg.sender] = pointsCorrectionETH[msg.sender].add(
            int256(pointsPerShareETH.mul(_amount))
        );

        // Note: For ERC20s, a loop over all historical dividend tokens would be gas prohibitive.
        // In a real MVP, you'd likely restrict the 'supported' dividend tokens or force a claim before stake.
        // For simplicity here, we assume ETH is the primary revenue. 
        // ERC20 corrections update happens lazily on claim if implemented fully.

        emit Staked(msg.sender, _amount);
    }

    /**
     * @dev Withdraw staked tokens.
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(stakes[msg.sender] >= _amount, "Insufficient stake");

        _distributePendingETH(msg.sender);

        totalStaked = totalStaked.sub(_amount);
        stakes[msg.sender] = stakes[msg.sender].sub(_amount);

        pointsCorrectionETH[msg.sender] = pointsCorrectionETH[msg.sender].sub(
            int256(pointsPerShareETH.mul(_amount))
        );

        moltToken.transfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    /**
     * @dev View claimable ETH.
     */
    function claimableETH(address _user) public view returns (uint256) {
        int256 _accumulated = int256(pointsPerShareETH.mul(stakes[_user]));
        int256 _correction = pointsCorrectionETH[_user];
        int256 _claimable = _accumulated.sub(_correction);
        
        if (_claimable < 0) return 0; // Should not happen with correct math
        return uint256(_claimable).div(MAGNITUDE);
    }

    /**
     * @dev Claim ETH dividends.
     */
    function claimETH() external nonReentrant {
        _distributePendingETH(msg.sender);
    }

    function _distributePendingETH(address _user) internal {
        uint256 _amount = claimableETH(_user);
        if (_amount > 0) {
            // Update correction to mark as claimed
            pointsCorrectionETH[_user] = pointsCorrectionETH[_user].add(
                int256(_amount.mul(MAGNITUDE))
            );
            
            withdrawnETH[_user] = withdrawnETH[_user].add(_amount);
            (bool success, ) = _user.call{value: _amount}("");
            require(success, "ETH transfer failed");
            
            emit ClaimedETH(_user, _amount);
        }
    }
    
    // Additional view and claim functions for ERC20 would follow the same pattern
    // requiring a specific token address to be passed in to avoid unbound loops.
}
