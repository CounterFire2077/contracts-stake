// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRewardDistributor {
  function rewardToken() external view returns (address);
  function tokensPerInterval() external view returns (uint256);
  function pendingRewards() external view returns (uint256);
  function distribute(uint256 _amount, uint256 _decimals) external returns (uint256);
}
