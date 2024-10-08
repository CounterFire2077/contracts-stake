// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRewardDistributor} from "./interfaces/IRewardDistributor.sol";
import {IRewardTracker} from "./interfaces/IRewardTracker.sol";
import {Governable} from "../core/Governable.sol";

contract RewardDistributor is IRewardDistributor, ReentrancyGuard, Governable {
  using SafeERC20 for IERC20;

  address public override rewardToken;
  uint256 public override tokensPerInterval;
  uint256 public lastDistributionTime;
  address public rewardTracker;

  address public admin;

  event Distribute(uint256 amount);
  event TokensPerIntervalChange(uint256 amount);

  modifier onlyAdmin() {
    require(msg.sender == admin, "RewardDistributor: forbidden");
    _;
  }

  constructor(address _rewardToken, address _rewardTracker) {
    rewardToken = _rewardToken;
    rewardTracker = _rewardTracker;
    admin = msg.sender;
  }

  function setAdmin(address _admin) external onlyGov {
    admin = _admin;
  }

  // to help users who accidentally send their tokens to this contract
  function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
    IERC20(_token).safeTransfer(_account, _amount);
  }

  function updateLastDistributionTime() external onlyAdmin {
    lastDistributionTime = block.timestamp;
  }

  function setTokensPerInterval(uint256 _amount) external onlyAdmin {
    require(lastDistributionTime != 0, "RewardDistributor: invalid lastDistributionTime");
    IRewardTracker(rewardTracker).updateRewards();
    tokensPerInterval = _amount;
    emit TokensPerIntervalChange(_amount);
  }

  function pendingRewards() public view override returns (uint256) {
    if (block.timestamp == lastDistributionTime) {
      return 0;
    }

    uint256 timeDiff = block.timestamp - lastDistributionTime;
    return tokensPerInterval * timeDiff;
  }

  function distribute(uint256 _amount, uint256 _decimals) external override returns (uint256) {
    require(msg.sender == rewardTracker, "RewardDistributor: invalid msg.sender");
    uint256 amount = pendingRewards();
    if (amount == 0) {
      return 0;
    }

    lastDistributionTime = block.timestamp;

    uint256 tokenAmount = amount * _amount / (10**_decimals);

    uint256 balance = IERC20(rewardToken).balanceOf(address(this));
    require(tokenAmount <= balance, "RewardDistributor: insufficient balance");
    
    IERC20(rewardToken).safeTransfer(msg.sender, tokenAmount);

    emit Distribute(tokenAmount);
    return amount;
  }
}
