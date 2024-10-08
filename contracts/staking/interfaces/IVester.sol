// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVester {
  function needCheckStake() external view returns (bool);
  function updateVesting(address _account) external;

  function rewardTracker() external view returns (address);

  function claimForAccount(address _account, address _receiver) external returns (uint256);

  function claimable(address _account) external view returns (uint256);
  function cumulativeClaimAmounts(address _account) external view returns (uint256);
  function claimedAmounts(address _account) external view returns (uint256);
  function pairAmounts(address _account) external view returns (uint256);
  function getVestedAmount(address _account) external view returns (uint256);
  function cumulativeRewardDeductions(address _account) external view returns (uint256);
  function bonusRewards(address _account) external view returns (uint256);

  function setCumulativeRewardDeductions(address _account, uint256 _amount) external;
  function setBonusRewards(address _account, uint256 _amount) external;

  function getMaxVestableAmount(address _account) external view returns (uint256);
  function getCombinedAverageStakedAmount(address _account) external view returns (uint256);
}
